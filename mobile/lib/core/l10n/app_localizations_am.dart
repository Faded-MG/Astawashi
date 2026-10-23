// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'አስታዋሽ';

  @override
  String get offlineDescription =>
      'የአካባቢ መዝገብዎ ያለ ኢንተርኔት ይገኛል። ለማመሳሰል በመስመር ላይ ሲሆኑ ይግቡ።';

  @override
  String get phoneLabel => 'ስልክ ቁጥር';

  @override
  String get pinLabel => 'ፒን';

  @override
  String get shopNameLabel => 'የሱቅ ስም (አማራጭ)';

  @override
  String get loginButton => 'ግባ';

  @override
  String get registerButton => 'የሱቅ መለያ ፍጠር';

  @override
  String get syncButton => 'አሁን አመሳስል';

  @override
  String get syncIdle => 'ለማመሳሰል ዝግጁ';

  @override
  String get syncInProgress => 'በማመሳሰል ላይ…';

  @override
  String get syncSucceeded => 'ማመሳሰል ተጠናቋል';

  @override
  String get syncFailed => 'ማመሳሰል አልተሳካም። የአካባቢ መዝገቦች አሁንም ተቀምጠዋል።';

  @override
  String get authenticationRequired =>
      'ለማመሳሰል ይግቡ። የአካባቢ መዝገቦች በዚህ መሣሪያ ላይ ይቆያሉ።';

  @override
  String get authenticationFailed => 'ማረጋገጫ አልተሳካም';

  @override
  String syncResult(int customers, int entries) {
    return '$customers ደንበኞች እና $entries የደብተር መዝገቦች ተልከዋል።';
  }
}
