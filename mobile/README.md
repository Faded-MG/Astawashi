# Astawash mobile app

The Flutter application is in active development. Its current screens cover onboarding, sign-in, dashboard, customers, ledger activity, and settings. Local ledger data is stored with Drift/SQLite; authenticated synchronization with the backend is available as a manual action.

For prerequisites, database/backend setup, environment configuration, Flutter commands, and test safety notes, see the [repository README](../README.md).

Run the app from this directory with:

```bash
flutter pub get
flutter run --dart-define=ASTAWASH_API_BASE_URL=http://10.0.2.2:3000
```

The URL above is for an Android emulator using a backend on the host machine. Use `http://localhost:3000` for an iOS simulator or desktop run.
