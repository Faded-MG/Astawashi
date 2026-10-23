import type { Pool, PoolClient, QueryResultRow } from 'pg';

import type {
  SyncCustomerRow,
  SyncEntryRow,
  SyncPullPage,
  SyncRepository,
} from './service.js';

type Queryable = Pick<Pool, 'query'>;

export class PostgresSyncRepository implements SyncRepository {
  constructor(
    private readonly pool: Pool,
    private readonly transactionClient?: PoolClient,
  ) {}

  private get queryable(): Queryable {
    return this.transactionClient ?? this.pool;
  }

  async withTransaction<T>(
    operation: (repository: SyncRepository) => Promise<T>,
  ): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT pg_advisory_xact_lock($1, $2)', [8192, 1]);
      const result = await operation(new PostgresSyncRepository(this.pool, client));
      await client.query('COMMIT');
      return result;
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        throw new AggregateError(
          [error, rollbackError],
          'Sync transaction failed and rollback also failed.',
        );
      }
      throw error;
    } finally {
      client.release();
    }
  }

  async upsertCustomer(customer: {
    id: string;
    shopId: string;
    name: string;
    phone: string | null;
    note: string | null;
    createdAt: string;
    updatedAt: string;
    deletedAt: string | null;
  }): Promise<boolean> {
    const result = await this.queryable.query<{ id: string }>(
      `
        INSERT INTO customers (id, shop_id, name, phone, note, created_at, updated_at, deleted_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          phone = EXCLUDED.phone,
          note = EXCLUDED.note,
          updated_at = EXCLUDED.updated_at,
          deleted_at = EXCLUDED.deleted_at,
          server_seq = nextval('change_seq')
        WHERE customers.shop_id = EXCLUDED.shop_id
        RETURNING id
      `,
      [
        customer.id,
        customer.shopId,
        customer.name,
        customer.phone,
        customer.note,
        customer.createdAt,
        customer.updatedAt,
        customer.deletedAt,
      ],
    );

    return result.rows.length > 0;
  }

  async insertEntry(entry: {
    id: string;
    shopId: string;
    customerId: string;
    kind: 'credit' | 'payment' | 'reversal';
    amountSantim: number;
    deltaSantim: number;
    reversesId: string | null;
    note: string | null;
    occurredAt: string;
    createdAt: string;
    deviceId: string;
  }): Promise<boolean> {
    const result = await this.queryable.query<{ id: string }>(
      `
        INSERT INTO ledger_entries (
          id, shop_id, customer_id, kind, amount_santim, delta_santim,
          reverses_id, note, occurred_at, created_at, device_id
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        ON CONFLICT (id) DO NOTHING
        RETURNING id
      `,
      [
        entry.id,
        entry.shopId,
        entry.customerId,
        entry.kind,
        entry.amountSantim,
        entry.deltaSantim,
        entry.reversesId,
        entry.note,
        entry.occurredAt,
        entry.createdAt,
        entry.deviceId,
      ],
    );

    return result.rows.length > 0;
  }

  async pullPage(shopId: string, since: number, limit: number): Promise<SyncPullPage> {
    const result = await this.queryable.query<
      QueryResultRow & { recordType: 'customer' | 'entry'; serverSeq: string }
    >(
      `
        SELECT *
        FROM (
          SELECT id, shop_id AS "shopId", name, phone, note,
                 created_at AS "createdAt", updated_at AS "updatedAt",
                 deleted_at AS "deletedAt", NULL::uuid AS "customerId",
                 NULL::text AS kind, NULL::integer AS "amountSantim",
                 NULL::integer AS "deltaSantim", NULL::uuid AS "reversesId",
                 note AS note_entry, NULL::timestamptz AS "occurredAt",
                 NULL::text AS "deviceId", server_seq AS "serverSeq",
                 'customer'::text AS "recordType"
          FROM customers
          WHERE shop_id = $1 AND server_seq > $2
          UNION ALL
          SELECT id, shop_id AS "shopId", NULL::text AS name, NULL::text AS phone,
                 NULL::text AS note, created_at AS "createdAt",
                 NULL::timestamptz AS "updatedAt", NULL::timestamptz AS "deletedAt",
                 customer_id AS "customerId", kind,
                 amount_santim AS "amountSantim", delta_santim AS "deltaSantim",
                 reverses_id AS "reversesId", note AS note_entry,
                 occurred_at AS "occurredAt", device_id AS "deviceId",
                 server_seq AS "serverSeq", 'entry'::text AS "recordType"
          FROM ledger_entries
          WHERE shop_id = $1 AND server_seq > $2
        ) AS changes
        ORDER BY "serverSeq" ASC, id ASC
        LIMIT $3
      `,
      [shopId, since, limit + 1],
    );

    const hasMore = result.rows.length > limit;
    const pageRows = hasMore ? result.rows.slice(0, limit) : result.rows;
    const customers = pageRows
      .filter((row) => row.recordType === 'customer')
      .map((row) => ({
        id: row.id as string,
        shopId: row.shopId as string,
        name: row.name as string,
        phone: row.phone as string | null,
        note: row.note_entry as string | null,
        createdAt: (row.createdAt as Date).toISOString(),
        updatedAt: (row.updatedAt as Date).toISOString(),
        deletedAt: row.deletedAt ? (row.deletedAt as Date).toISOString() : null,
        serverSeq: safeSequenceNumber(row.serverSeq),
      }));
    const entries = pageRows
      .filter((row) => row.recordType === 'entry')
      .map((row) => ({
        id: row.id as string,
        shopId: row.shopId as string,
        customerId: row.customerId as string,
        kind: row.kind as SyncEntryRow['kind'],
        amountSantim: row.amountSantim as number,
        deltaSantim: row.deltaSantim as number,
        reversesId: row.reversesId as string | null,
        note: row.note_entry as string | null,
        occurredAt: (row.occurredAt as Date).toISOString(),
        createdAt: (row.createdAt as Date).toISOString(),
        deviceId: row.deviceId as string,
        serverSeq: safeSequenceNumber(row.serverSeq),
      }));
    const lastRow = pageRows.at(-1);

    return {
      customers,
      entries,
      hasMore,
      nextCursor: lastRow ? safeSequenceNumber(lastRow.serverSeq) : null,
    };
  }

  async customerExistsForShop(shopId: string, customerId: string): Promise<boolean> {
    const result = await this.queryable.query(
      'SELECT 1 FROM customers WHERE shop_id = $1 AND id = $2 LIMIT 1',
      [shopId, customerId],
    );
    return result.rows.length > 0;
  }

  async getEntryById(entryId: string): Promise<SyncEntryRow | null> {
    const result = await this.queryable.query(
      `${entrySelectSql} WHERE id = $1`,
      [entryId],
    );
    return result.rows[0] ? mapEntry(result.rows[0]) : null;
  }

  async getEntryByIdForShop(shopId: string, entryId: string): Promise<SyncEntryRow | null> {
    const result = await this.queryable.query(
      `${entrySelectSql} WHERE shop_id = $1 AND id = $2`,
      [shopId, entryId],
    );
    return result.rows[0] ? mapEntry(result.rows[0]) : null;
  }

  async getReversalForEntry(shopId: string, entryId: string): Promise<SyncEntryRow | null> {
    const result = await this.queryable.query(
      `${entrySelectSql} WHERE shop_id = $1 AND reverses_id = $2 AND kind = 'reversal' LIMIT 1`,
      [shopId, entryId],
    );
    return result.rows[0] ? mapEntry(result.rows[0]) : null;
  }

  async getCustomerById(customerId: string): Promise<SyncCustomerRow | null> {
    const result = await this.queryable.query(
      `${customerSelectSql} WHERE id = $1`,
      [customerId],
    );
    return result.rows[0] ? mapCustomer(result.rows[0]) : null;
  }

  async getCustomerByIdForShop(
    shopId: string,
    customerId: string,
  ): Promise<SyncCustomerRow | null> {
    const result = await this.queryable.query(
      `${customerSelectSql} WHERE shop_id = $1 AND id = $2`,
      [shopId, customerId],
    );
    return result.rows[0] ? mapCustomer(result.rows[0]) : null;
  }
}

const entrySelectSql = `
  SELECT id, shop_id AS "shopId", customer_id AS "customerId", kind,
         amount_santim AS "amountSantim", delta_santim AS "deltaSantim",
         reverses_id AS "reversesId", note, occurred_at AS "occurredAt",
         created_at AS "createdAt", device_id AS "deviceId",
         server_seq::text AS "serverSeq"
  FROM ledger_entries
`;

const customerSelectSql = `
  SELECT id, shop_id AS "shopId", name, phone, note,
         created_at AS "createdAt", updated_at AS "updatedAt",
         deleted_at AS "deletedAt", server_seq::text AS "serverSeq"
  FROM customers
`;

function mapEntry(row: QueryResultRow): SyncEntryRow {
  return {
    id: row.id as string,
    shopId: row.shopId as string,
    customerId: row.customerId as string,
    kind: row.kind as SyncEntryRow['kind'],
    amountSantim: row.amountSantim as number,
    deltaSantim: row.deltaSantim as number,
    reversesId: row.reversesId as string | null,
    note: row.note as string | null,
    occurredAt: (row.occurredAt as Date).toISOString(),
    createdAt: (row.createdAt as Date).toISOString(),
    deviceId: row.deviceId as string,
    serverSeq: safeSequenceNumber(row.serverSeq as string),
  };
}

function mapCustomer(row: QueryResultRow): SyncCustomerRow {
  return {
    id: row.id as string,
    shopId: row.shopId as string,
    name: row.name as string,
    phone: row.phone as string | null,
    note: row.note as string | null,
    createdAt: (row.createdAt as Date).toISOString(),
    updatedAt: (row.updatedAt as Date).toISOString(),
    deletedAt: row.deletedAt ? (row.deletedAt as Date).toISOString() : null,
    serverSeq: safeSequenceNumber(row.serverSeq as string),
  };
}

function safeSequenceNumber(value: string): number {
  const sequence = Number(value);
  if (!Number.isSafeInteger(sequence) || sequence < 0) {
    throw new Error('Database sync sequence exceeds the supported safe integer range.');
  }
  return sequence;
}
