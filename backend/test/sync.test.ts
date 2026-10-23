import { describe, expect, it } from 'vitest';

import {
  SyncService,
  syncEntrySchema,
  type SyncCustomerRow,
  type SyncEntryRow,
  type SyncRepository,
} from '../src/modules/sync/service.js';

function createInMemorySyncRepository(
  shouldFailEntryInsert: () => boolean = () => false,
): SyncRepository {
  const customers = new Map<string, SyncCustomerRow>();
  const entries = new Map<string, SyncEntryRow>();
  let nextSeq = 1;

  const assignSeq = <T extends { serverSeq: number }>(row: T): T => ({
    ...row,
    serverSeq: nextSeq++,
  });

  return {
    async withTransaction(operation) {
      const customerSnapshot = new Map(
        [...customers].map(([id, row]) => [id, { ...row }]),
      );
      const entrySnapshot = new Map(
        [...entries].map(([id, row]) => [id, { ...row }]),
      );
      const sequenceSnapshot = nextSeq;
      try {
        return await operation(this);
      } catch (error) {
        customers.clear();
        for (const [id, row] of customerSnapshot) {
          customers.set(id, row);
        }
        entries.clear();
        for (const [id, row] of entrySnapshot) {
          entries.set(id, row);
        }
        nextSeq = sequenceSnapshot;
        throw error;
      }
    },
    async upsertCustomer(customer) {
      const existing = customers.get(customer.id);
      if (!existing) {
        customers.set(customer.id, assignSeq({ ...customer, serverSeq: 0 }));
        return true;
      }

      const incomingUpdatedAt = new Date(customer.updatedAt).getTime();
      const existingUpdatedAt = new Date(existing.updatedAt).getTime();
      if (incomingUpdatedAt < existingUpdatedAt) {
        return false;
      }

      customers.set(customer.id, {
        ...existing,
        ...customer,
        serverSeq: nextSeq++,
      });
      return true;
    },
    async insertEntry(entry) {
      if (shouldFailEntryInsert()) {
        throw new Error('Simulated database write failure.');
      }
      if (entries.has(entry.id)) {
        return false;
      }
      entries.set(entry.id, assignSeq({ ...entry, serverSeq: 0 }));
      return true;
    },
    async pullPage(shopId: string, since: number, limit: number) {
      const customerRows = [...customers.values()]
        .filter((row) => row.shopId === shopId && row.serverSeq > since)
        .sort((a, b) => a.serverSeq - b.serverSeq);
      const entryRows = [...entries.values()]
        .filter((row) => row.shopId === shopId && row.serverSeq > since)
        .sort((a, b) => a.serverSeq - b.serverSeq);

      const combined = [...customerRows, ...entryRows].sort((a, b) => a.serverSeq - b.serverSeq);
      const page = combined.slice(0, limit);

      return {
        customers: page.filter((row): row is SyncCustomerRow => 'name' in row) as SyncCustomerRow[],
        entries: page.filter((row): row is SyncEntryRow => 'customerId' in row) as SyncEntryRow[],
        hasMore: combined.length > limit,
        nextCursor: page[page.length - 1]?.serverSeq ?? null,
      };
    },
    async customerExistsForShop(shopId: string, customerId: string) {
      const customer = customers.get(customerId);
      return Boolean(customer && customer.shopId === shopId);
    },
    async getEntryById(entryId: string) {
      return entries.get(entryId) ?? null;
    },
    async getEntryByIdForShop(shopId: string, entryId: string) {
      const entry = entries.get(entryId);
      return entry && entry.shopId === shopId ? entry : null;
    },
    async getCustomerByIdForShop(shopId: string, customerId: string) {
      const customer = customers.get(customerId);
      return customer && customer.shopId === shopId ? customer : null;
    },
    async getCustomerById(customerId: string) {
      return customers.get(customerId) ?? null;
    },
    async getReversalForEntry(shopId: string, entryId: string) {
      for (const entry of entries.values()) {
        if (entry.shopId === shopId && entry.kind === 'reversal' && entry.reversesId === entryId) {
          return entry;
        }
      }
      return null;
    },
  };
}

describe('SyncService', () => {
  it('accepts a valid customer and entry payload', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    const result = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [
        {
          id: '11111111-1111-4111-8111-111111111111',
          name: 'Abebe',
          phone: '+251911000000',
          note: 'Regular',
          createdAt: '2026-10-12T08:00:00.000Z',
          updatedAt: '2026-10-12T08:00:00.000Z',
          deletedAt: null,
        },
      ],
      entries: [
        {
          id: '22222222-2222-4222-8222-222222222222',
          customerId: '11111111-1111-4111-8111-111111111111',
          kind: 'credit',
          amountSantim: 15000,
          deltaSantim: 15000,
          note: 'sale',
          occurredAt: '2026-10-12T08:10:00.000Z',
          createdAt: '2026-10-12T08:10:00.000Z',
          deviceId: 'device-1',
        },
      ],
    });

    expect(result.acceptedCustomerIds).toEqual(['11111111-1111-4111-8111-111111111111']);
    expect(result.acceptedEntryIds).toEqual(['22222222-2222-4222-8222-222222222222']);
  });

  it('treats repeated identical pushes as idempotent', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    const payload = {
      deviceId: 'device-1',
      customers: [{
        id: '33333333-3333-4333-8333-333333333333',
        name: 'Chaltu',
        phone: '+251922000000',
        note: null,
        createdAt: '2026-10-12T09:00:00.000Z',
        updatedAt: '2026-10-12T09:00:00.000Z',
        deletedAt: null,
      }],
      entries: [{
        id: '44444444-4444-4444-8444-444444444444',
        customerId: '33333333-3333-4333-8333-333333333333',
        kind: 'payment',
        amountSantim: 5000,
        deltaSantim: -5000,
        note: 'payment',
        occurredAt: '2026-10-12T09:20:00.000Z',
        createdAt: '2026-10-12T09:20:00.000Z',
        deviceId: 'device-1',
      }],
    };

    const first = await service.push('shop-1', payload);
    const second = await service.push('shop-1', payload);

    expect(first.acceptedCustomerIds).toHaveLength(1);
    expect(second.alreadyAcceptedCustomerIds).toContain('33333333-3333-4333-8333-333333333333');
    expect(second.alreadyAcceptedEntryIds).toContain('44444444-4444-4444-8444-444444444444');
  });

  it('rejects conflicting duplicate UUIDs and cross-shop access', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [{
        id: '66666666-6666-4666-8666-666666666666',
        name: 'Customer',
        phone: '+251933333333',
        note: null,
        createdAt: '2026-10-12T09:50:00.000Z',
        updatedAt: '2026-10-12T09:50:00.000Z',
        deletedAt: null,
      }],
      entries: [{
        id: '55555555-5555-4555-8555-555555555555',
        customerId: '66666666-6666-4666-8666-666666666666',
        kind: 'credit',
        amountSantim: 1000,
        deltaSantim: 1000,
        note: 'first',
        occurredAt: '2026-10-12T10:00:00.000Z',
        createdAt: '2026-10-12T10:00:00.000Z',
        deviceId: 'device-1',
      }],
    });

    const conflicting = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: '55555555-5555-4555-8555-555555555555',
        customerId: '66666666-6666-4666-8666-666666666666',
        kind: 'credit',
        amountSantim: 1000,
        deltaSantim: 2000,
        note: 'different',
        occurredAt: '2026-10-12T10:05:00.000Z',
        createdAt: '2026-10-12T10:05:00.000Z',
        deviceId: 'device-1',
      }],
    });

    const crossShop = await service.push('shop-2', {
      deviceId: 'device-2',
      customers: [],
      entries: [{
        id: '77777777-7777-4777-8777-777777777777',
        customerId: '66666666-6666-4666-8666-666666666666',
        kind: 'credit',
        amountSantim: 3000,
        deltaSantim: 3000,
        note: 'other-shop',
        occurredAt: '2026-10-12T11:20:00.000Z',
        createdAt: '2026-10-12T11:20:00.000Z',
        deviceId: 'device-2',
      }],
    });

    expect(conflicting.rejectedEntries[0]?.reason).toContain('conflicting immutable');
    expect(crossShop.rejectedEntries[0]?.reason).toContain('Customer does not belong to this shop');
  });

  it('does not overwrite a customer UUID owned by another shop', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    const customerId = '88888888-8888-4888-8888-888888888888';
    await service.push('shop-1', {
      customers: [{
        id: customerId,
        name: 'Original',
        createdAt: '2026-10-12T09:00:00.000Z',
        updatedAt: '2026-10-12T09:00:00.000Z',
      }],
      entries: [],
    });

    const result = await service.push('shop-2', {
      customers: [{
        id: customerId,
        name: 'Attempted overwrite',
        createdAt: '2026-10-12T10:00:00.000Z',
        updatedAt: '2026-10-12T10:00:00.000Z',
      }],
      entries: [],
    });

    expect(result.rejectedCustomers[0]?.reason).toContain('another shop');
    expect(await service.pull('shop-1', { since: 0, limit: 10 })).toMatchObject({
      customers: [{ name: 'Original' }],
    });
    expect(await service.pull('shop-2', { since: 0, limit: 10 })).toMatchObject({
      customers: [],
    });
  });

  it('rolls back every change when a database write fails during a batch', async () => {
    let failInsert = true;
    const repository = createInMemorySyncRepository(() => failInsert);
    const service = new SyncService(repository);
    const payload = {
      customers: [{
        id: '98989898-9898-4989-8989-989898989898',
        name: 'Rollback customer',
        createdAt: '2026-10-12T09:00:00.000Z',
        updatedAt: '2026-10-12T09:00:00.000Z',
      }],
      entries: [{
        id: '97979797-9797-4979-8979-979797979797',
        customerId: '98989898-9898-4989-8989-989898989898',
        kind: 'credit' as const,
        amountSantim: 100,
        deltaSantim: 100,
        occurredAt: '2026-10-12T09:10:00.000Z',
        createdAt: '2026-10-12T09:10:00.000Z',
        deviceId: 'device-1',
      }],
    };

    await expect(service.push('shop-1', payload)).rejects.toThrow(
      'Simulated database write failure',
    );
    expect(await service.pull('shop-1', { since: 0, limit: 10 })).toMatchObject({
      customers: [],
      entries: [],
    });

    failInsert = false;
    const retried = await service.push('shop-1', payload);
    expect(retried.acceptedCustomerIds).toContain('98989898-9898-4989-8989-989898989898');
    expect(retried.acceptedEntryIds).toContain('97979797-9797-4979-8979-979797979797');
  });

  it('rejects invalid amount, delta, and reversal rules', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    const customerId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [{
        id: customerId,
        name: 'Guest',
        phone: '+251955555555',
        note: null,
        createdAt: '2026-10-12T12:00:00.000Z',
        updatedAt: '2026-10-12T12:00:00.000Z',
        deletedAt: null,
      }],
      entries: [],
    });

    const badAmount = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        customerId,
        kind: 'credit',
        amountSantim: 0,
        deltaSantim: 0,
        note: 'bad',
        occurredAt: '2026-10-12T12:05:00.000Z',
        createdAt: '2026-10-12T12:05:00.000Z',
        deviceId: 'device-1',
      }],
    });

    expect(badAmount.rejectedEntries[0]?.reason).toContain('greater than zero');

    const badReversal = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        customerId,
        kind: 'reversal',
        amountSantim: 200,
        deltaSantim: -100,
        reversesId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        note: 'bad reversal',
        occurredAt: '2026-10-12T12:10:00.000Z',
        createdAt: '2026-10-12T12:10:00.000Z',
        deviceId: 'device-1',
      }],
    });

    expect(badReversal.rejectedEntries[0]?.reason).toContain('Reversal target');
    expect(() => syncEntrySchema.parse({ amountSantim: 0 })).toThrow();
  });

  it('accepts valid reversals and rejects duplicate reversal attempts', async () => {
    const service = new SyncService(createInMemorySyncRepository());
    const customerId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
    await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [{
        id: customerId,
        name: 'Reversal customer',
        phone: '+251966666666',
        note: null,
        createdAt: '2026-10-12T13:00:00.000Z',
        updatedAt: '2026-10-12T13:00:00.000Z',
        deletedAt: null,
      }],
      entries: [],
    });

    const initial = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        customerId,
        kind: 'credit',
        amountSantim: 1000,
        deltaSantim: 1000,
        note: 'initial',
        occurredAt: '2026-10-12T13:10:00.000Z',
        createdAt: '2026-10-12T13:10:00.000Z',
        deviceId: 'device-1',
      }],
    });
    expect(initial.acceptedEntryIds).toContain('ffffffff-ffff-4fff-8fff-ffffffffffff');

    const reversal = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: '12121212-1212-4121-8121-121212121212',
        customerId,
        kind: 'reversal',
        amountSantim: 1000,
        deltaSantim: -1000,
        reversesId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        note: 'reversal',
        occurredAt: '2026-10-12T13:15:00.000Z',
        createdAt: '2026-10-12T13:15:00.000Z',
        deviceId: 'device-1',
      }],
    });
    expect(reversal.acceptedEntryIds).toContain('12121212-1212-4121-8121-121212121212');

    const duplicateReversal = await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [],
      entries: [{
        id: '13131313-1313-4131-8131-131313131313',
        customerId,
        kind: 'reversal',
        amountSantim: 1000,
        deltaSantim: -1000,
        reversesId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        note: 'duplicate reversal',
        occurredAt: '2026-10-12T13:25:00.000Z',
        createdAt: '2026-10-12T13:25:00.000Z',
        deviceId: 'device-1',
      }],
    });
    expect(duplicateReversal.rejectedEntries[0]?.reason).toContain('already been reversed');
  });

  it('pulls a deterministic page and advances the cursor safely', async () => {
    const repository = createInMemorySyncRepository();
    const service = new SyncService(repository);
    await service.push('shop-1', {
      deviceId: 'device-1',
      customers: [{
        id: '14141414-1414-4141-8141-141414141414',
        name: 'A',
        phone: '+251971111111',
        note: null,
        createdAt: '2026-10-12T14:00:00.000Z',
        updatedAt: '2026-10-12T14:00:00.000Z',
        deletedAt: null,
      }],
      entries: [{
        id: '15151515-1515-4151-8151-151515151515',
        customerId: '14141414-1414-4141-8141-141414141414',
        kind: 'credit',
        amountSantim: 2000,
        deltaSantim: 2000,
        note: 'sale',
        occurredAt: '2026-10-12T14:05:00.000Z',
        createdAt: '2026-10-12T14:05:00.000Z',
        deviceId: 'device-1',
      }],
    });

    const firstPage = await service.pull('shop-1', { since: 0, limit: 1 });
    expect(firstPage.hasMore).toBe(true);
    expect(firstPage.customers.length + firstPage.entries.length).toBe(1);
    expect(firstPage.nextCursor).not.toBeNull();

    const secondPage = await service.pull('shop-1', { since: firstPage.nextCursor ?? 0, limit: 10 });
    expect(secondPage.customers.length + secondPage.entries.length).toBeGreaterThan(0);
    expect(secondPage.hasMore).toBe(false);
    expect(secondPage.nextCursor).not.toBeNull();

    const emptyPage = await service.pull('shop-1', {
      since: secondPage.nextCursor ?? 0,
      limit: 10,
    });
    expect(emptyPage.customers).toEqual([]);
    expect(emptyPage.entries).toEqual([]);
    expect(emptyPage.nextCursor).toBeNull();
  });
});
