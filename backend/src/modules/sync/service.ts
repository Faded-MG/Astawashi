import { z } from 'zod';

export const syncCustomerSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  phone: z.string().trim().max(20).nullable().optional(),
  note: z.string().trim().max(500).nullable().optional(),
  createdAt: z.string().datetime({ offset: true }),
  updatedAt: z.string().datetime({ offset: true }),
  deletedAt: z.string().datetime({ offset: true }).nullable().optional(),
});

export const syncEntrySchema = z.object({
  id: z.string().uuid(),
  customerId: z.string().uuid(),
  kind: z.enum(['credit', 'payment', 'reversal']),
  amountSantim: z.coerce.number().int(),
  deltaSantim: z.coerce.number().int(),
  reversesId: z.string().uuid().nullable().optional(),
  note: z.string().trim().max(500).nullable().optional(),
  occurredAt: z.string().datetime({ offset: true }),
  createdAt: z.string().datetime({ offset: true }),
  deviceId: z.string().trim().min(1).max(120),
});

export const syncPushRequestSchema = z.object({
  deviceId: z.string().trim().min(1).max(120).optional(),
  customers: z.array(syncCustomerSchema).max(200).default([]),
  entries: z.array(syncEntrySchema).max(200).default([]),
});

export const syncPullQuerySchema = z.object({
  since: z.coerce.number().int().nonnegative().default(0),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export interface SyncCustomerRow {
  id: string;
  shopId: string;
  name: string;
  phone: string | null;
  note: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
  serverSeq: number;
}

export interface SyncEntryRow {
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
  serverSeq: number;
}

export interface SyncPushResult {
  acceptedCustomerIds: string[];
  acceptedEntryIds: string[];
  alreadyAcceptedCustomerIds: string[];
  alreadyAcceptedEntryIds: string[];
  rejectedCustomers: Array<{ id: string; reason: string }>;
  rejectedEntries: Array<{ id: string; reason: string }>;
}

export interface SyncPullPage {
  customers: SyncCustomerRow[];
  entries: SyncEntryRow[];
  hasMore: boolean;
  nextCursor: number | null;
}

export interface SyncRepository {
  upsertCustomer(customer: {
    id: string;
    shopId: string;
    name: string;
    phone: string | null;
    note: string | null;
    createdAt: string;
    updatedAt: string;
    deletedAt: string | null;
  }): Promise<boolean>;
  insertEntry(entry: {
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
  }): Promise<boolean>;
  pullPage(shopId: string, since: number, limit: number): Promise<SyncPullPage>;
  customerExistsForShop(shopId: string, customerId: string): Promise<boolean>;
  getEntryByIdForShop(shopId: string, entryId: string): Promise<SyncEntryRow | null>;
  getReversalForEntry(shopId: string, entryId: string): Promise<SyncEntryRow | null>;
  getCustomerByIdForShop(shopId: string, customerId: string): Promise<SyncCustomerRow | null>;
}

export class SyncService {
  constructor(private readonly repository: SyncRepository) {}

  async push(
    shopId: string,
    raw: z.infer<typeof syncPushRequestSchema>,
  ): Promise<SyncPushResult> {
    const payload = syncPushRequestSchema.parse(raw);
    const totalChanges = payload.customers.length + payload.entries.length;
    if (totalChanges > 200) {
      throw new Error('A sync batch may contain at most 200 changes.');
    }

    const acceptedCustomerIds: string[] = [];
    const acceptedEntryIds: string[] = [];
    const alreadyAcceptedCustomerIds: string[] = [];
    const alreadyAcceptedEntryIds: string[] = [];
    const rejectedCustomers: Array<{ id: string; reason: string }> = [];
    const rejectedEntries: Array<{ id: string; reason: string }> = [];

    for (const customer of payload.customers) {
      const existing = await this.repository.getCustomerByIdForShop(shopId, customer.id);
      if (existing && existing.shopId !== shopId) {
        rejectedCustomers.push({ id: customer.id, reason: 'Customer belongs to another shop.' });
        continue;
      }

      const normalized = {
        id: customer.id,
        shopId,
        name: customer.name,
        phone: customer.phone ?? null,
        note: customer.note ?? null,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
        deletedAt: customer.deletedAt ?? null,
      };

      if (!existing) {
        const inserted = await this.repository.upsertCustomer(normalized);
        if (inserted) {
          acceptedCustomerIds.push(customer.id);
        } else {
          alreadyAcceptedCustomerIds.push(customer.id);
        }
        continue;
      }

      const samePayload =
        existing.name === normalized.name &&
        (existing.phone ?? null) === normalized.phone &&
        (existing.note ?? null) === normalized.note &&
        existing.createdAt === normalized.createdAt &&
        existing.updatedAt === normalized.updatedAt &&
        (existing.deletedAt ?? null) === normalized.deletedAt;

      if (samePayload) {
        alreadyAcceptedCustomerIds.push(customer.id);
        continue;
      }

      const incomingUpdatedAt = new Date(normalized.updatedAt).getTime();
      const existingUpdatedAt = new Date(existing.updatedAt).getTime();
      if (incomingUpdatedAt < existingUpdatedAt) {
        rejectedCustomers.push({
          id: customer.id,
          reason: 'Customer update is older than the server version.',
        });
        continue;
      }

      await this.repository.upsertCustomer(normalized);
      acceptedCustomerIds.push(customer.id);
    }

    for (const entry of payload.entries) {
      const customerExists = await this.repository.customerExistsForShop(shopId, entry.customerId);
      if (!customerExists) {
        rejectedEntries.push({
          id: entry.id,
          reason: 'Customer does not belong to this shop.',
        });
        continue;
      }

      const existing = await this.repository.getEntryByIdForShop(shopId, entry.id);
      const normalized = {
        id: entry.id,
        shopId,
        customerId: entry.customerId,
        kind: entry.kind,
        amountSantim: entry.amountSantim,
        deltaSantim: entry.deltaSantim,
        reversesId: entry.reversesId ?? null,
        note: entry.note ?? null,
        occurredAt: entry.occurredAt,
        createdAt: entry.createdAt,
        deviceId: entry.deviceId,
      };

      if (existing) {
        const samePayload =
          existing.customerId === normalized.customerId &&
          existing.kind === normalized.kind &&
          existing.amountSantim === normalized.amountSantim &&
          existing.deltaSantim === normalized.deltaSantim &&
          (existing.reversesId ?? null) === normalized.reversesId &&
          (existing.note ?? null) === normalized.note &&
          existing.occurredAt === normalized.occurredAt &&
          existing.createdAt === normalized.createdAt &&
          existing.deviceId === normalized.deviceId;

        if (samePayload) {
          alreadyAcceptedEntryIds.push(entry.id);
          continue;
        }

        rejectedEntries.push({
          id: entry.id,
          reason: 'Ledger entry UUID already exists with conflicting immutable content.',
        });
        continue;
      }

      const validation = await this.validateEntryAgainstShopRules(shopId, entry, existing);
      if (!validation.valid) {
        rejectedEntries.push({ id: entry.id, reason: validation.reason ?? 'Invalid entry.' });
        continue;
      }

      const inserted = await this.repository.insertEntry(normalized);
      if (inserted) {
        acceptedEntryIds.push(entry.id);
      } else {
        alreadyAcceptedEntryIds.push(entry.id);
      }
    }

    return {
      acceptedCustomerIds,
      acceptedEntryIds,
      alreadyAcceptedCustomerIds,
      alreadyAcceptedEntryIds,
      rejectedCustomers,
      rejectedEntries,
    };
  }

  async pull(
    shopId: string,
    raw: z.infer<typeof syncPullQuerySchema>,
  ): Promise<SyncPullPage> {
    const query = syncPullQuerySchema.parse(raw);
    return this.repository.pullPage(shopId, query.since, query.limit);
  }

  private async validateEntryAgainstShopRules(
    shopId: string,
    entry: z.infer<typeof syncEntrySchema>,
    existing: SyncEntryRow | null,
  ): Promise<{ valid: boolean; reason?: string }> {
    if (entry.amountSantim <= 0) {
      return { valid: false, reason: 'Entry amount must be greater than zero.' };
    }

    if (entry.kind === 'credit' && entry.deltaSantim !== entry.amountSantim) {
      return { valid: false, reason: 'Credit entries must have delta equal to amount.' };
    }

    if (entry.kind === 'payment' && entry.deltaSantim !== -entry.amountSantim) {
      return { valid: false, reason: 'Payment entries must have delta equal to -amount.' };
    }

    if (entry.kind === 'reversal') {
      if (!entry.reversesId) {
        return { valid: false, reason: 'Reversal entries must specify reversesId.' };
      }

      const target = await this.repository.getEntryByIdForShop(shopId, entry.reversesId);
      if (!target) {
        return { valid: false, reason: 'Reversal target does not exist in this shop.' };
      }

      if (target.kind === 'reversal') {
        return { valid: false, reason: 'Reversal entries cannot reverse another reversal.' };
      }

      const reversalAlreadyExists = await this.repository.getReversalForEntry(shopId, entry.reversesId);
      if (reversalAlreadyExists) {
        return { valid: false, reason: 'This ledger entry has already been reversed.' };
      }

      const reversedTarget = await this.repository.getEntryByIdForShop(shopId, entry.reversesId);
      if (!reversedTarget) {
        return { valid: false, reason: 'Reversal target does not exist in this shop.' };
      }

      if (entry.deltaSantim !== -target.deltaSantim) {
        return { valid: false, reason: 'Reversal delta must negate the original delta.' };
      }

      if (entry.amountSantim !== target.amountSantim) {
        return { valid: false, reason: 'Reversal amount must match the original amount.' };
      }
    }

    if (entry.kind !== 'reversal' && entry.reversesId) {
      return { valid: false, reason: 'Only reversal entries may specify reversesId.' };
    }

    if (existing && existing.shopId !== shopId) {
      return { valid: false, reason: 'Entry belongs to another shop.' };
    }

    return { valid: true };
  }
}
