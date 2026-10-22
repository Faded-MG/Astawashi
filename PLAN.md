# Astawash — Solo Build Plan

## 1. Rating: 7.5 / 10

| Criterion | Score | Why |
|---|---|---|
| Problem relevance | 9 | Dube (credit) is everywhere in Ethiopian kiosks; paper notebooks are the real competitor. |
| Technical depth | 8 | Offline-first + idempotent sync + financial integrity is a genuinely strong CTC story. |
| Solo feasibility | 6 | Sync is the risk. Everything else is routine CRUD. Manageable only if scope stays frozen. |
| Differentiation | 6 | Khatabook / OkCredit exist. Your edge: Amharic-first, offline-first, local reminder habits, no payment gateway. |
| Evaluation story | 7 | Strong if you test with 3–5 real shopkeepers. Weak if you only test yourself. |

**What lifts it to 9:** a working offline→online sync demo, balance correctness proven by tests, and real usability numbers (seconds to record a sale).
**What sinks it:** a pretty UI with sync that loses or duplicates entries.

---

## 2. What To Build First

Order matters. Build the thing that proves the idea first.

1. **Domain + local DB + balance logic (with unit tests).** No UI yet. This is the heart.
2. **Local-only app.** Customers, credit, repayment, balances, history. Fully usable with zero backend. This alone is a demoable product.
3. **Backend + auth.**
4. **Sync** (push first, then pull).
5. **Amharic/English + reminders.**
6. **Testing, usability evaluation, documentation.**

**Cut line if time runs out (drop from the bottom):** background auto-sync → pull sync → reminders polish → English/Amharic toggle at runtime. Never cut: local ledger, push sync, idempotency, balance tests.

---

## 3. Architecture

### Overview

```
┌────────────────────── Flutter App ──────────────────────┐
│  UI (feature screens)                                   │
│    ↓ watches                                            │
│  Riverpod providers / controllers                       │
│    ↓ calls                                              │
│  Repositories (single entry point to data)              │
│    ↓                         ↓                          │
│  Drift (SQLite)  ←── SyncEngine ──→  API client (Dio)   │
│  SOURCE OF TRUTH         outbox                         │
└──────────────────────────────┬──────────────────────────┘
                               │ HTTPS (only when online)
┌──────────────────────────────┴──────────────────────────┐
│  Node.js API (Fastify + TS)                             │
│  routes → services → SQL                                │
│  /auth  /sync/push  /sync/pull                          │
└──────────────────────────────┬──────────────────────────┘
                               │
                        PostgreSQL
```

### Why this architecture (decisions and reasoning)

**1. Local SQLite is the source of truth, not the server.**
The UI only ever reads and writes the local DB. The network is a background concern. This is what makes the app work identically online and offline: there is no "offline mode", there is only "sync hasn't happened yet". It also makes the UI fast and removes loading spinners from the core flow (recording a sale takes milliseconds).

**2. Append-only ledger (events, not mutable balances).**
A customer's balance is never stored as a number you edit. It is always `SUM(delta)` over that customer's ledger entries.
- Credit sale → `delta = +amount` (customer owes more)
- Repayment → `delta = -amount`
- Mistake → add a **reversal** entry with `delta = -(original delta)` and `reverses_id` pointing to the original. Never edit or delete.

Why: two devices (or two syncs) can never "overwrite" each other's balance, because entries are only ever added. Immutable records means **transactions cannot conflict**, which removes the hardest part of sync. It also gives you a free audit trail, which is exactly the "integrity of financial records" objective.

**3. Money as integer santim.**
`amount_santim INTEGER`. 25.50 birr = 2550. No floats anywhere, ever. Format to birr only in the UI layer.

**4. Client-generated UUIDs (v7) as idempotency keys.**
The app assigns every customer and ledger entry its ID at creation, offline. The server inserts with `ON CONFLICT (id) DO NOTHING`. If the phone retries a push five times because the connection dropped, the entry exists exactly once. This is your answer to "duplicate synchronization requests". UUIDv7 is time-ordered, so it indexes well.

**5. Outbox pattern for push.**
Every locally created row has `synced_at = NULL`. The SyncEngine selects unsynced rows, sends them in a batch, and marks them synced only after the server confirms. A crash mid-sync is safe because re-sending is harmless (see #4).

**6. Server sequence cursor for pull.**
Every insert/update on the server stamps `server_seq = nextval('change_seq')`. Clients pull `GET /sync/pull?since=<last_seq>` and store the highest seq they received. No timestamps compared across devices, so no clock-skew bugs.

**7. Conflict policy (simple and defensible).**
- Ledger entries: immutable → no conflicts.
- Customers (name/phone/note edits): last-write-wins by `updated_at`; soft-delete via `deleted_at`.
- v1 assumes one shop = mostly one device, but the design is already safe for two.

**8. Auth: phone + PIN, JWT access + refresh.**
No SMS OTP (costs money, needs network, bad fit). The server stores an Argon2 hash of the PIN. After first login the app works fully offline; the token is only needed at sync time. Expired token + offline = sync pauses, recording continues.

**9. Reminders are local, not server-sent.**
The app builds a localized message ("ሰላም {name}, ብር {amount} ዱቤ አለቦት…") and opens the SMS app with it pre-filled via `sms:` URI (url_launcher). Zero cost, works offline, and fits "prepare repayment reminders" in scope without a messaging provider.

### Tech Choices

**Mobile (Flutter)**
- State: `flutter_riverpod`
- Routing: `go_router`
- Local DB: `drift` (typed SQLite, migrations, streams that auto-update UI)
- HTTP: `dio`
- Connectivity: `connectivity_plus`
- Secure storage: `flutter_secure_storage` (tokens)
- i18n: `flutter_localizations` + `intl` ARB files (`app_en.arb`, `app_am.arb`)
- Fonts: **bundle** Noto Sans Ethiopic in assets (do not fetch at runtime, you're offline-first)
- IDs: `uuid` (v7)
- Reminders: `url_launcher`

**Backend**
- Fastify + TypeScript, `zod` validation
- `pg` + plain SQL migrations (`node-pg-migrate`), no ORM, so you control `ON CONFLICT` and sequences
- `argon2`, `@fastify/jwt`, `@fastify/rate-limit`
- Tests: `vitest` against a Docker Postgres
- Local: `docker compose` (Postgres)
- Deploy: Render / Railway / Fly free tier

### Folder Structure (feature-first)

```
astawash/
├── mobile/
│   └── lib/
│       ├── main.dart
│       ├── app/                 # router, theme, app widget
│       ├── core/
│       │   ├── db/              # drift database, tables, migrations
│       │   ├── money/           # santim helpers, formatters
│       │   ├── sync/            # SyncEngine, outbox, api client
│       │   ├── l10n/            # arb files, locale controller
│       │   └── utils/
│       └── features/
│           ├── auth/            # data/ domain/ presentation/
│           ├── customers/
│           ├── ledger/          # credit, repayment, reversal, balance logic
│           ├── reminders/
│           └── settings/
├── backend/
│   ├── src/
│   │   ├── server.ts
│   │   ├── config/
│   │   ├── db/                  # pool, migrations/
│   │   └── modules/
│   │       ├── auth/
│   │       └── sync/
│   └── test/
├── docker-compose.yml
├── PLAN.md
└── .cursor/rules/astawash.mdc
```

---

## 4. Data Model

**Local (SQLite via drift) and server (Postgres) share the same shape.**

```
customers
  id            uuid  PK  (client-generated)
  shop_id       uuid
  name          text  NOT NULL
  phone         text
  note          text
  created_at    int/timestamptz
  updated_at    int/timestamptz
  deleted_at    nullable
  synced_at     nullable          -- local only
  server_seq    bigint nullable   -- server-assigned

ledger_entries
  id            uuid  PK  (client-generated, idempotency key)
  shop_id       uuid
  customer_id   uuid  FK
  kind          text  CHECK IN ('credit','payment','reversal')
  amount_santim integer NOT NULL CHECK (amount_santim > 0)
  delta_santim  integer NOT NULL   -- +credit, -payment, reversal = -(original delta)
  reverses_id   uuid nullable FK -> ledger_entries.id
  note          text
  occurred_at   timestamp
  created_at    timestamp
  device_id     text
  synced_at     nullable          -- local only
  server_seq    bigint nullable   -- server-assigned

sync_state (local only)
  last_pull_seq integer
```

Server additionally: `shops`, `users (phone unique, pin_hash, shop_id)`, `refresh_tokens`.
Rules: **no UPDATE or DELETE on `ledger_entries`**, ever. A reversal can only target an entry that has no reversal yet (enforce with a unique index on `reverses_id`).

**Balance:** `SELECT COALESCE(SUM(delta_santim),0) FROM ledger_entries WHERE customer_id = ?`

---

## 5. Sync Protocol

**Push** `POST /sync/push` (auth required)
```json
{ "deviceId": "...", "customers": [ ... ], "entries": [ ... ] }
```
- Single DB transaction. Customers upserted first (LWW on `updated_at`), then entries `INSERT ... ON CONFLICT (id) DO NOTHING`.
- Validate: entry's `shop_id` matches the token's shop, `customer_id` exists, `amount > 0`, `delta` is consistent with `kind`.
- Response: `{ "acceptedCustomerIds": [...], "acceptedEntryIds": [...] }` (duplicates count as accepted).
- Client marks those IDs `synced_at = now`. Batch size ≤ 200.

**Pull** `GET /sync/pull?since=<seq>&limit=500`
- Returns customers + entries with `server_seq > since` for the shop, ordered by seq, plus `nextSeq` and `hasMore`.
- Client upserts by `id` (entries insert-if-absent), stores `nextSeq`, loops while `hasMore`.

**Trigger points:** app start, after every local write (debounced 3 s), connectivity restored, manual "Sync now" button. Skip background workers until everything else is done.

**Failure rules:** network error → leave `synced_at` NULL, retry with backoff; 401 → stop sync, keep recording; 4xx validation error on one item → mark that item `sync_error` and continue (don't block the queue).

---

## 6. Timeline (compact work sessions)

Estimates assume focused sessions with Cursor generating most boilerplate. Total ≈ 15–18 h.

### Session 0 — Setup (≈ 45 min)
- [ ] Create repo, add `PLAN.md` and `.cursor/rules/astawash.mdc`
- [ ] `flutter create mobile`, add packages, bundle Noto Sans Ethiopic
- [ ] Backend scaffold + `docker-compose.yml` with Postgres
- [ ] Paste the starter prompt into Cursor
**Done when:** app runs on a device, `docker compose up` gives a working DB.

### Session 1 — Core ledger, local only (≈ 4 h) ← biggest chunk, do this in one sitting
- [ ] Drift tables: customers, ledger_entries, sync_state + migration
- [ ] Money helpers (santim ⇄ birr)
- [ ] Ledger repository: addCredit, addPayment, reverseEntry, watchBalance, watchHistory
- [ ] **Unit tests:** credit, partial payment, overpayment rule, reversal, balance = sum, reversal-of-reversal blocked
- [ ] Screens: customer list (with balances) → customer detail (history) → add credit / add payment sheets
- [ ] Total outstanding on the home screen
**Done when:** you can run a full day of fake shop activity in airplane mode, and tests pass.

### Session 2 — Backend + auth (≈ 3 h)
- [ ] Migrations: shops, users, customers, ledger_entries, `change_seq`, indexes
- [ ] `/auth/register`, `/auth/login`, `/auth/refresh` (phone + PIN, Argon2, JWT)
- [ ] Rate limit on login, zod validation, auth hook
- [ ] Mobile: login/register screens, secure token storage, "skip until online" path
**Done when:** register and login work from the app; Postman/curl tests pass.

### Session 3 — Sync (≈ 4 h)
- [ ] `/sync/push` with idempotent inserts + validation
- [ ] `/sync/pull` with cursor
- [ ] Backend tests: duplicate push, partial batch, cross-shop rejection, pull pagination
- [ ] SyncEngine on mobile: outbox select → push → mark synced → pull → apply
- [ ] Sync status indicator (pending count, last synced), "Sync now"
- [ ] Manual scenario test: record offline → reconnect → verify on server; kill app mid-sync → rerun → no duplicates
**Done when:** the duplicate-sync test is green and the airplane-mode demo works end to end.

### Session 4 — Bilingual + reminders (≈ 2 h)
- [ ] ARB files en/am, language switch in settings, persisted
- [ ] Amharic digits/formatting decision (use Latin digits, recommended)
- [ ] Reminder list: customers with balance > 0, sorted by amount or age
- [ ] Localized SMS template + `sms:` launch
**Done when:** whole app flips language and a reminder opens prefilled in the SMS app.

### Session 5 — Hardening + evaluation + docs (≈ 3 h)
- [ ] App PIN/biometric lock (`local_auth`), optional
- [ ] Empty states, error states, large-number formatting, low-end device check
- [ ] Usability test with 3–5 shopkeepers: time to record a credit sale, register a repayment, find who owes most. Write down numbers.
- [ ] README, architecture diagram, test summary, screenshots
**Done when:** you have usability timings and a clean README.

---

## 7. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Sync scope creep | Push-only first, pull after. Ledger is immutable so no merge logic. |
| Amharic text rendering/input bugs | Bundle the font, test on a real low-end Android early (Session 1, not Session 4). |
| Running out of time | Follow the cut line in section 2. Session 1 alone is a presentable product. |
| Cursor drifting from the architecture | Always-on rule file + one-step-at-a-time prompts. Review every DB/money change. |
| No real users for evaluation | Line up 3 shopkeepers (family, neighbors) before Session 5. |
