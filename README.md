# Astawash · አስታዋሽ

**An offline-first customer-credit ledger for neighborhood shops.**

Astawash helps shopkeepers record customer credit and repayments, review balances, and synchronize records with a backend when connected. The project is under active development.

**Project:** Mahlet Getinet · CTC-1238-26 · INSA 2026, 5th Batch · Development Department · Room 3004 · **Instructor:** Muhamadawal

## Current functionality

- Customer records, customer details, and balance filters.
- Credit sales, repayments, ledger history, and reversals.
- A dashboard with total outstanding and recent activity.
- Local persistence with Drift and SQLite.
- Phone-and-PIN registration and sign-in against the backend.
- Authenticated push and pull synchronization, triggered manually in the app.
- English and Amharic interface strings and a bundled Noto Sans Ethiopic font.

Automatic/background synchronization and SMS reminders are not currently available. The app is still under development; review the source and tests for the current behavior.

## Architecture

- **Mobile:** Flutter, Riverpod, go_router, Drift/SQLite, Dio, and secure token storage.
- **Backend:** Node.js, Fastify, TypeScript, Zod, and PostgreSQL.
- **Ledger:** amounts are stored as integer santim. Ledger entries are append-only; corrections use reversals.
- **Sync:** authenticated `/sync/push` and `/sync/pull` endpoints use idempotent entry IDs and a server sequence cursor.

## Repository layout

```text
backend/
  src/                 API server, auth/sync modules, database pool and migrations
  test/                Backend unit and PostgreSQL integration tests
mobile/
  lib/app/             Routing, providers, theme and shared widgets
  lib/core/            Database, localization, money and sync
  lib/features/        Auth, customers, dashboard, ledger and settings
  test/                Flutter unit, widget and integration tests
  assets/fonts/        Bundled Ethiopic font and its license
docker-compose.yml     Local PostgreSQL service
PLAN.md                Architecture, data model and project plan
```

## Prerequisites

- Flutter with a Dart SDK compatible with `mobile/pubspec.yaml`.
- Node.js and npm.
- Docker Compose and an Android emulator/device or iOS simulator for mobile runs.

## Local setup

### PostgreSQL

From the repository root, start the local PostgreSQL 16 service:

```bash
docker compose up -d
```

The Compose file supplies development-only database settings. Do not reuse them for a deployed environment.

### Backend

```bash
cd backend
npm ci
npm run migrate:local
npm run build
npm test
npm start
```

The API listens on port `3000` by default. Check liveness and database readiness with:

```bash
curl --fail http://localhost:3000/health
curl --fail http://localhost:3000/ready
```

### Production configuration and migrations

Set `NODE_ENV=production`, a `JWT_SECRET` of at least 32 characters, and an explicit `DATABASE_URL` in the backend runtime environment. The server also accepts `PORT`, `ACCESS_TOKEN_TTL_SECONDS`, `REFRESH_TOKEN_TTL_SECONDS`, `LOGIN_RATE_LIMIT_MAX`, and `LOGIN_RATE_LIMIT_WINDOW_MS`. Do not put real credentials or secrets in source control.

`npm run migrate:local` explicitly targets the local Docker Compose database. `npm run migrate` requires `DATABASE_URL` to be supplied and is intended for a deliberately selected database target. Before migrating, verify the target database and back up important data. Apply migrations deliberately before routing traffic to a new deployment.

The PostgreSQL integration tests in `backend/test/sync.postgres.test.ts` require `TEST_DATABASE_URL` to point to a disposable, migrated database whose name contains `test`. Do not use production data for tests.

### Mobile

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
```

To run on an Android emulator against the local backend:

```bash
flutter run --dart-define=ASTAWASH_API_BASE_URL=http://10.0.2.2:3000
```

For an iOS simulator or desktop run, use `http://localhost:3000` as the API URL. Set `ASTAWASH_API_BASE_URL` to the deployed HTTPS API URL for a non-local environment.

The live mobile-to-backend test creates temporary accounts and ledger records on the configured API. Run it only against a disposable test service:

```bash
ASTAWASH_TEST_API_BASE_URL=http://localhost:3000 \
  flutter test test/core/sync/live_sync_e2e_test.dart
```

## API endpoints

- `GET /health` — process liveness.
- `GET /ready` — database readiness.
- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me` — authentication.
- `POST /sync/push`, `GET /sync/pull` — authenticated synchronization.

## Further documentation

- [Project plan and data model](PLAN.md)
- [Project rules](.cursor/rules/astawash.mdc)
- [Git workflow](.cursor/rules/git-workflow.mdc)
