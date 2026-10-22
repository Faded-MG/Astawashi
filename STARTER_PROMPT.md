# Cursor Starter Prompt (paste into Agent mode, new chat)

Copy only the text between the two lines of ``` below. Do not copy the ``` lines.

```
Read PLAN.md, .cursor/rules/astawash.mdc and .cursor/rules/git-workflow.mdc fully before doing anything.

Project: Astawash, an offline-first customer-credit ledger for Ethiopian shops.
Stack: Flutter (Riverpod, go_router, drift, dio) + Node/Fastify/TypeScript + PostgreSQL.
I am building solo and I have limited time. Work in small, runnable steps.

Step 0 (do this first, no code yet):
Follow git-workflow.mdc sections 1 and 9. Inspect branch, working tree, remotes, commits, files and manifests. Deliver the repository audit and proposed feature timeline: evidence-supported milestones, uncertain ones, what to implement next. Mark roadmap items completed / partially completed / unverified / planned by evidence only. Do not modify history. Wait for my "go".

Task: Session 0 setup, then Session 1 (core ledger, local only).

Session 0 (branch: chore/project-scaffold):
1. Create monorepo layout from PLAN.md section 3: mobile/, backend/, docker-compose.yml (Postgres 16).
2. mobile/: flutter create, add only the packages listed in PLAN.md "Tech Choices", set up folder structure (app/, core/, features/), register bundled Noto Sans Ethiopic in pubspec (assets/fonts/), configure flutter_localizations with empty app_en.arb and app_am.arb.
3. backend/: npm init, TypeScript strict, Fastify, zod, pg, vitest. Health route GET /health only.
4. Give me the exact commands to run and verify. Stop.

Session 1 (after I confirm Session 0 works; one branch per numbered item, e.g. feat/money-helpers, feat/offline-storage, feat/ledger-repository, feat/customer-management, feat/ledger-ui):
1. mobile/lib/core/money/: santim <-> birr helpers and formatter. Unit tests.
2. mobile/lib/core/db/: drift tables customers, ledger_entries, sync_state exactly as in PLAN.md section 4. Include a unique index on reverses_id.
3. mobile/lib/features/ledger/: repository with addCredit, addPayment, reverseEntry, watchBalance(customerId), watchHistory(customerId), watchTotalOutstanding. UUIDv7 ids, device_id, synced_at null on create.
4. Unit tests (in-memory drift): credit, partial payment, full payment, reversal, double-reversal blocked, reversal of a reversal blocked, balance equals sum, amount must be > 0.
5. features/customers/: repository (create, update, soft delete, watch list with balance).
6. UI: customer list with balances and total outstanding, customer detail with history, bottom sheets for add credit / add payment. Strings from ARB (en + am). Plain, large touch targets.

Rules for this session:
- One numbered step at a time. After each step, report in the git-workflow.mdc section 7 format and wait for my "next".
- Complete files only, no partial diffs.
- No network code, no auth, no sync yet.
- Commit and push feature branches only after tests pass. Open a PR. Never merge without my explicit approval.
- If anything in PLAN.md is ambiguous, ask one short question instead of guessing.

Start with Step 0.
```

## Follow-up prompts (use when each session starts)

**Session 2:** `Session 2 from PLAN.md: backend migrations, auth (register/login/refresh, phone + PIN, Argon2, JWT), rate limit, then mobile login/register with secure token storage and a "continue offline" path. Follow git-workflow.mdc. One step at a time.`

**Session 3:** `Session 3 from PLAN.md: /sync/push (idempotent, single transaction, validation), /sync/pull (server_seq cursor), backend tests first, then mobile SyncEngine with outbox. Follow git-workflow.mdc. One step at a time.`

**Session 4:** `Session 4 from PLAN.md: full en/am ARB coverage with persisted language switch, reminder list, localized SMS template via sms: URI. Follow git-workflow.mdc. One step at a time.`

**Session 5:** `Session 5 from PLAN.md: empty/error states, large-number formatting, optional app lock, README with architecture diagram. Follow git-workflow.mdc. List what is missing before writing anything.`
