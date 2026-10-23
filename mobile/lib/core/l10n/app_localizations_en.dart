// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Astawash';

  @override
  String get offlineDescription =>
      'Your local ledger stays available without internet. Sign in when you are online to synchronize.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get pinLabel => 'PIN';

  @override
  String get shopNameLabel => 'Shop name (optional)';

  @override
  String get loginButton => 'Sign in';

  @override
  String get registerButton => 'Create shop account';

  @override
  String get syncButton => 'Synchronize now';

  @override
  String get syncIdle => 'Ready to synchronize';

  @override
  String get syncInProgress => 'Synchronizing…';

  @override
  String get syncSucceeded => 'Synchronization complete';

  @override
  String get syncFailed =>
      'Synchronization failed. Local records are still saved.';

  @override
  String get authenticationRequired =>
      'Sign in to synchronize. Local records remain on this device.';

  @override
  String get authenticationFailed => 'Authentication failed';

  @override
  String syncResult(int customers, int entries) {
    return 'Sent $customers customers and $entries ledger entries.';
  }
}
