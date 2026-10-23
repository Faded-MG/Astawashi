import type { Pool } from 'pg';

import type {
  SyncCustomerRow,
  SyncEntryRow,
  SyncPullPage,
  SyncRepository,
} from './service.js';

export class PostgresSyncRepository implements SyncRepository {
  constructor(private readonly pool: Pool) {}

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
    const result = await this.pool.query<{ id: string }>(
      `
        INSERT INTO customers (id, shop_id, name, phone, note, created_at, updated_at, deleted_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          phone = EXCLUDED.phone,
          note = EXCLUDED.note,
          updated_at = EXCLUDED.updated_at,
          deleted_at = EXCLUDED.deleted_at
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

    return Boolean(result.rowCount && result.rowCount > 0);
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
    const result = await this.pool.query<{ id: string }>(
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

    return Boolean(result.rowCount && result.rowCount > 0);
  }

  async pullPage(shopId: string, since: number, limit: number): Promise<SyncPullPage> {
    const customerRows = await this.pool.query<SyncCustomerRow>(
      `
        SELECT id, shop_id AS "shopId", name, phone, note,
               created_at AS "createdAt", updated_at AS "updatedAt",
               deleted_at AS "deletedAt", server_seq AS "serverSeq"
        FROM customers
        WHERE shop_id = $1 AND server_seq > $2
        ORDER BY server_seq ASC, id ASC
        LIMIT $3
      `,
      [shopId, since, limit],
    );

    const entryRows = await this.pool.query<SyncEntryRow>(
      `
        SELECT id, shop_id AS "shopId", customer_id AS "customerId", kind,
               amount_santim AS "amountSantim", delta_santim AS "deltaSantim",
               reverses_id AS "reversesId", note, occurred_at AS "occurredAt",
               created_at AS "createdAt", device_id AS "deviceId",
               server_seq AS "serverSeq"
        FROM ledger_entries
        WHERE shop_id = $1 AND server_seq > $2
        ORDER BY server_seq ASC, id ASC
        LIMIT $3
      `,
      [shopId, since, limit],
    );

    const combined = [
      ...customerRows.rows.map((row) => ({ ...row, __kind: 'customer' as const })),
      ...entryRows.rows.map((row) => ({ ...row, __kind: 'entry' as const })),
    ].sort((left, right) => left.serverSeq - right.serverSeq || left.id.localeCompare(right.id));

    const pageSize = Math.min(limit, combined.length);
    const page = combined.slice(0, pageSize);

    return {
      customers: page
        .filter((row) => row.__kind === 'customer')
        .map((row) => row as SyncCustomerRow),
      entries: page
        .filter((row) => row.__kind === 'entry')
        .map((row) => row as SyncEntryRow),
      hasMore: combined.length > pageSize,
      nextCursor: combined.length > pageSize ? combined[pageSize - 1]?.serverSeq ?? null : null,
    };
  }

  async customerExistsForShop(shopId: string, customerId: string): Promise<boolean> {
    const result = await this.pool.query<{ id: string }>(
      'SELECT 1 FROM customers WHERE shop_id = $1 AND id = $2 LIMIT 1',
      [shopId, customerId],
    );
    return Boolean(result.rowCount && result.rowCount > 0);
  }

  async getEntryByIdForShop(shopId: string, entryId: string): Promise<SyncEntryRow | null> {
    const result = await this.pool.query<SyncEntryRow>(
      `
        SELECT id, shop_id AS "shopId", customer_id AS "customerId", kind,
               amount_santim AS "amountSantim", delta_santim AS "deltaSantim",
               reverses_id AS "reversesId", note, occurred_at AS "occurredAt",
               created_at AS "createdAt", device_id AS "deviceId",
               server_seq AS "serverSeq"
        FROM ledger_entries
        WHERE shop_id = $1 AND id = $2
      `,
      [shopId, entryId],
    );

    return result.rows[0] ?? null;
  }

  async getReversalForEntry(shopId: string, entryId: string): Promise<SyncEntryRow | null> {
    const result = await this.pool.query<SyncEntryRow>(
      `
        SELECT id, shop_id AS "shopId", customer_id AS "customerId", kind,
               amount_santim AS "amountSantim", delta_santim AS "deltaSantim",
               reverses_id AS "reversesId", note, occurred_at AS "occurredAt",
               created_at AS "createdAt", device_id AS "deviceId",
               server_seq AS "serverSeq"
        FROM ledger_entries
        WHERE shop_id = $1 AND reverses_id = $2 AND kind = 'reversal'
        LIMIT 1
      `,
      [shopId, entryId],
    );

    return result.rows[0] ?? null;
  }

  async getCustomerByIdForShop(shopId: string, customerId: string): Promise<SyncCustomerRow | null> {
    const result = await this.pool.query<SyncCustomerRow>(
      `
        SELECT id, shop_id AS "shopId", name, phone, note,
               created_at AS "createdAt", updated_at AS "updatedAt",
               deleted_at AS "deletedAt", server_seq AS "serverSeq"
        FROM customers
        WHERE shop_id = $1 AND id = $2
      `,
      [shopId, customerId],
    );

    return result.rows[0] ?? null;
  }
}
