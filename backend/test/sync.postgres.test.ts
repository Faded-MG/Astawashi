import { randomUUID } from 'node:crypto';

import { Pool } from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PostgresSyncRepository } from '../src/modules/sync/repository.js';
import { SyncService } from '../src/modules/sync/service.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
if (
  databaseUrl &&
  !/(?:^|[_-])test(?:[_-]|$)/i.test(new URL(databaseUrl).pathname.slice(1))
) {
  throw new Error('TEST_DATABASE_URL must point to a disposable database with "test" in its name.');
}
const postgresDescribe = databaseUrl ? describe : describe.skip;

postgresDescribe('PostgreSQL sync integration', () => {
  const pool = new Pool({ connectionString: databaseUrl });
  const service = new SyncService(new PostgresSyncRepository(pool));

  beforeAll(async () => {
    await pool.query(`
      CREATE OR REPLACE FUNCTION astawash_test_fail_sync_entry()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.device_id = 'rollback-trigger' THEN
          RAISE EXCEPTION 'simulated sync persistence failure';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await pool.query(`
      DROP TRIGGER IF EXISTS astawash_test_fail_sync_entry_trigger
      ON ledger_entries
    `);
    await pool.query(`
      CREATE TRIGGER astawash_test_fail_sync_entry_trigger
      BEFORE INSERT ON ledger_entries
      FOR EACH ROW EXECUTE FUNCTION astawash_test_fail_sync_entry()
    `);
  });

  afterAll(async () => {
    await pool.query(`
      DROP TRIGGER IF EXISTS astawash_test_fail_sync_entry_trigger
      ON ledger_entries
    `);
    await pool.query('DROP FUNCTION IF EXISTS astawash_test_fail_sync_entry()');
    await pool.end();
  });

  it('runs migrations schema and keeps pushes idempotent with duplicate conflict rejection', async () => {
    const shopId = await createShop('Sync idempotency');
    const customerId = randomUUID();
    const entryId = randomUUID();
    const payload = {
      customers: [customer(customerId, 'Abebe')],
      entries: [entry(entryId, customerId)],
    };

    const first = await service.push(shopId, payload);
    const repeated = await service.push(shopId, payload);
    const conflicting = await service.push(shopId, {
      customers: [],
      entries: [entry(entryId, customerId, { note: 'conflict' })],
    });

    expect(first.acceptedCustomerIds).toEqual([customerId]);
    expect(first.acceptedEntryIds).toEqual([entryId]);
    expect(repeated.alreadyAcceptedCustomerIds).toEqual([customerId]);
    expect(repeated.alreadyAcceptedEntryIds).toEqual([entryId]);
    expect(conflicting.rejectedEntries[0]?.reason).toContain('conflicting immutable');
    await expect(
      pool.query('UPDATE ledger_entries SET note = $1 WHERE id = $2', ['edited', entryId]),
    ).rejects.toThrow('ledger_entries is append-only');
    await expect(
      pool.query('DELETE FROM ledger_entries WHERE id = $1', [entryId]),
    ).rejects.toThrow('ledger_entries is append-only');
  });

  it('isolates shop data and prevents UUID ownership overwrite', async () => {
    const ownerShop = await createShop('Owner');
    const otherShop = await createShop('Other');
    const customerId = randomUUID();
    const otherCustomerId = randomUUID();
    const originalEntryId = randomUUID();
    await service.push(ownerShop, {
      customers: [customer(customerId, 'Owner customer')],
      entries: [entry(originalEntryId, customerId)],
    });

    const customerCollision = await service.push(otherShop, {
      customers: [customer(customerId, 'Overwritten customer')],
      entries: [],
    });
    const entryCollision = await service.push(otherShop, {
      customers: [customer(otherCustomerId, 'Other customer')],
      entries: [entry(originalEntryId, otherCustomerId)],
    });

    expect(customerCollision.rejectedCustomers).toHaveLength(1);
    expect(entryCollision.rejectedEntries).toHaveLength(1);
    const otherShopPage = await service.pull(otherShop, { since: 0, limit: 20 });
    expect(otherShopPage.customers.map((row) => row.id)).toEqual([otherCustomerId]);
    expect(otherShopPage.entries).toEqual([]);
  });

  it('enforces reversal rules and returns a safe sequence cursor for each page', async () => {
    const shopId = await createShop('Reversals');
    const customerId = randomUUID();
    const differentCustomerId = randomUUID();
    const originalEntryId = randomUUID();
    await service.push(shopId, {
      customers: [
        customer(customerId, 'Reversal customer'),
        customer(differentCustomerId, 'Different customer'),
      ],
      entries: [entry(originalEntryId, customerId)],
    });

    const reversalId = randomUUID();
    const reversal = entry(reversalId, customerId, {
      kind: 'reversal',
      amountSantim: 1200,
      deltaSantim: -1200,
      reversesId: originalEntryId,
    });
    expect((await service.push(shopId, { customers: [], entries: [reversal] }))
      .acceptedEntryIds).toEqual([reversalId]);

    const duplicate = await service.push(shopId, {
      customers: [],
      entries: [
        entry(randomUUID(), customerId, {
          kind: 'reversal',
          amountSantim: 1200,
          deltaSantim: -1200,
          reversesId: originalEntryId,
        }),
      ],
    });
    const reversalOfReversal = await service.push(shopId, {
      customers: [],
      entries: [
        entry(randomUUID(), customerId, {
          kind: 'reversal',
          amountSantim: 1200,
          deltaSantim: 1200,
          reversesId: reversalId,
        }),
      ],
    });
    expect(duplicate.rejectedEntries[0]?.reason).toContain('already been reversed');
    expect(reversalOfReversal.rejectedEntries[0]?.reason).toContain(
      'cannot reverse another reversal',
    );
    const crossCustomerReversal = await service.push(shopId, {
      customers: [],
      entries: [
        entry(randomUUID(), differentCustomerId, {
          kind: 'reversal',
          amountSantim: 1200,
          deltaSantim: -1200,
          reversesId: originalEntryId,
        }),
      ],
    });
    expect(crossCustomerReversal.rejectedEntries[0]?.reason).toContain(
      'customer must match',
    );

    const firstPage = await service.pull(shopId, { since: 0, limit: 1 });
    expect(firstPage.customers.length + firstPage.entries.length).toBe(1);
    expect(firstPage.hasMore).toBe(true);
    expect(firstPage.nextCursor).not.toBeNull();
    const secondPage = await service.pull(shopId, {
      since: firstPage.nextCursor!,
      limit: 10,
    });
    expect(secondPage.nextCursor).not.toBeNull();
    expect(secondPage.hasMore).toBe(false);
    const empty = await service.pull(shopId, {
      since: secondPage.nextCursor!,
      limit: 10,
    });
    expect(empty.customers).toEqual([]);
    expect(empty.entries).toEqual([]);
    expect(empty.nextCursor).toBeNull();
  });

  it('assigns a new cursor sequence when customer details are updated', async () => {
    const shopId = await createShop('Customer updates');
    const customerId = randomUUID();
    const entryId = randomUUID();
    await service.push(shopId, {
      customers: [customer(customerId, 'Before update')],
      entries: [entry(entryId, customerId)],
    });

    const initialPage = await service.pull(shopId, { since: 0, limit: 10 });
    const initialCustomer = initialPage.customers[0];
    expect(initialCustomer).toBeDefined();
    const update = customer(customerId, 'After update');
    update.updatedAt = '2026-10-23T18:05:00.000Z';
    const pushResult = await service.push(shopId, {
      customers: [update],
      entries: [],
    });
    const changedPage = await service.pull(shopId, {
      since: initialPage.nextCursor!,
      limit: 10,
    });

    expect(pushResult.acceptedCustomerIds).toEqual([customerId]);
    expect(changedPage.customers).toMatchObject([
      { id: customerId, name: 'After update' },
    ]);
    expect(changedPage.customers[0]!.serverSeq).toBeGreaterThan(
      initialCustomer!.serverSeq,
    );
  });

  it('rolls back all changes when a database write fails during push', async () => {
    const shopId = await createShop('Rollback');
    const customerId = randomUUID();
    const payload = {
      customers: [customer(customerId, 'Must rollback')],
      entries: [
        entry(randomUUID(), customerId, {
          deviceId: 'rollback-trigger',
        }),
      ],
    };

    await expect(service.push(shopId, payload)).rejects.toThrow(
      'simulated sync persistence failure',
    );
    expect(await pool.query('SELECT id FROM customers WHERE id = $1', [customerId]))
      .toMatchObject({ rows: [] });
  });

  async function createShop(name: string): Promise<string> {
    const result = await pool.query<{ id: string }>(
      'INSERT INTO shops (name) VALUES ($1) RETURNING id',
      [name],
    );
    const id = result.rows[0]!.id;
    return id;
  }
});

function customer(id: string, name: string) {
  const timestamp = '2026-10-23T18:00:00.000Z';
  return {
    id,
    name,
    phone: null,
    note: null,
    createdAt: timestamp,
    updatedAt: timestamp,
    deletedAt: null,
  };
}

function entry(
  id: string,
  customerId: string,
  overrides: Partial<{
    kind: 'credit' | 'payment' | 'reversal';
    amountSantim: number;
    deltaSantim: number;
    reversesId: string | null;
    note: string | null;
    deviceId: string;
  }> = {},
) {
  const timestamp = '2026-10-23T18:01:00.000Z';
  return {
    id,
    customerId,
    kind: overrides.kind ?? 'credit',
    amountSantim: overrides.amountSantim ?? 1200,
    deltaSantim: overrides.deltaSantim ?? 1200,
    reversesId: overrides.reversesId ?? null,
    note: overrides.note ?? null,
    occurredAt: timestamp,
    createdAt: timestamp,
    deviceId: overrides.deviceId ?? 'integration-test',
  };
}
