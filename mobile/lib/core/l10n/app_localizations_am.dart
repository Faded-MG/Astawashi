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
  String get appTagline => 'ሒሳብዎን ይያዙ። አብረው ያድጉ።';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get confirm => 'አረጋግጥ';

  @override
  String get delete => 'አጥፋ';

  @override
  String get edit => 'አስተካክል';

  @override
  String get back => 'ተመለስ';

  @override
  String get search => 'ፈልግ';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get loading => 'በመጫን ላይ...';

  @override
  String get error => 'ስህተት ተከስቷል';

  @override
  String get empty => 'ምንም መረጃ አልተገኘም';

  @override
  String get birr => 'ብር';

  @override
  String get etb => 'ብር';

  @override
  String get skip => 'ዝለል';

  @override
  String get next => 'ቀጣይ';

  @override
  String get getStarted => 'ጀምር';

  @override
  String get onboardingTitle1 => 'የዱቤ ሒሳብዎን በቀላሉ ይያዙ';

  @override
  String get onboardingDesc1 =>
      'ያለ ኢንተርኔት ግንኙነትም ቢሆን የዱቤ ሽያጭና ክፍያን በሰከንዶች ውስጥ ይመዝግቡ።';

  @override
  String get onboardingTitle2 => 'ትሁት የኤስኤምኤስ ማስታወሻዎች';

  @override
  String get onboardingDesc2 =>
      'ለደንበኞችዎ በአንድ ጠቅታ ጨዋነትና ግልጽነት የተሞላበት የክፍያ ማስታወሻ በኤስኤምኤስ ይላኩ።';

  @override
  String get onboardingTitle3 => 'ሙሉ በሙሉ ያለ ኢንተርኔት ይሰራል';

  @override
  String get onboardingDesc3 =>
      'መረጃዎ በስልክዎ ላይ በደህንነት ይቀመጣል፤ ኢንተርኔት ሲኖር በራስ-ሰር ይሰምራል።';

  @override
  String get signIn => 'ግባ';

  @override
  String get welcomeBack => 'እንኳን ደህና መጡ';

  @override
  String get signInSubtitle =>
      'ሱቅዎን ለመክፈት የስልክ ቁጥርዎን እና ባለ 4 አሃዝ ሚስጥር ቁጥር ያስገቡ።';

  @override
  String get phoneNumber => 'የስልክ ቁጥር';

  @override
  String get phoneHint => '09XXXXXXXX';

  @override
  String get pin => 'ባለ 4 አሃዝ ፒን (PIN)';

  @override
  String get pinHint => '••••';

  @override
  String get enterValidPhone => 'ትክክለኛ የኢትዮጵያ ስልክ ቁጥር ያስገቡ';

  @override
  String get enterValidPin => 'ሚስጥር ቁጥሩ 4 አሃዝ መሆን አለበት';

  @override
  String get continueOffline => 'ያለ ኢንተርኔት ቀጥል';

  @override
  String get offlineShopNotice => 'መለያ ሳያስገቡም ሽያጭና ደንበኞችን በስልክዎ ላይ መመዝገብ ይችላሉ።';

  @override
  String get dashboard => 'ዳሽቦርድ';

  @override
  String get totalOutstanding => 'አጠቃላይ ያልተከፈለ ዱቤ';

  @override
  String customersWithBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ያልተከፈለ ሒሳብ ያለባቸው ደንበኞች',
      one: '1 ያልተከፈለ ሒሳብ ያለበት ደንበኛ',
    );
    return '$_temp0';
  }

  @override
  String get newCreditSale => 'አዲስ ዱቤ';

  @override
  String get recordRepayment => 'ክፍያ መመዝገብ';

  @override
  String get addCustomer => 'ደንበኛ መዝግብ';

  @override
  String get recentActivity => 'የቅርብ ጊዜ እንቅስቃሴዎች';

  @override
  String get viewAll => 'ሁሉንም እይ';

  @override
  String get noRecentActivity => 'ምንም የቅርብ ጊዜ ዝውውሮች የሉም። ለመጀመር ሽያጭ ይመዝግቡ።';

  @override
  String get syncStatusSynced => 'የሰመረ';

  @override
  String syncStatusPending(int count) {
    return '$count ያልተላከ';
  }

  @override
  String get syncStatusOffline => 'ኢንተርኔት የለም';

  @override
  String get customers => 'ደንበኞች';

  @override
  String get searchCustomersHint => 'በስም ወይም በስልክ ቁጥር ፈልግ...';

  @override
  String get filterAll => 'ሁሉም';

  @override
  String get filterWithBalance => 'ያልተከፈለ';

  @override
  String get filterSettled => 'የተጠናቀቀ';

  @override
  String get owesLabel => 'ያለበት';

  @override
  String get settledLabel => 'የተከፈለ';

  @override
  String get newCustomerTitle => 'አዲስ ደንበኛ መመዝገቢያ';

  @override
  String get customerName => 'የደንበኛ ስም';

  @override
  String get customerNameHint => 'ለምሳሌ፡ አበበ ከበደ';

  @override
  String get customerPhone => 'ስልክ ቁጥር (አማራጭ)';

  @override
  String get customerNote => 'ማስታወሻ (አማራጭ)';

  @override
  String get customerNoteHint => 'ለምሳሌ፡ ቤት ቁጥር 14';

  @override
  String get saveCustomer => 'ደንበኛ መዝግብ';

  @override
  String get customerAddedSuccess => 'ደንበኛ በተሳካ ሁኔታ ተመዝግቧል';

  @override
  String get noCustomersFound => 'ምንም ደንበኛ አልተገኘም';

  @override
  String get callCustomer => 'ደውል';

  @override
  String get sendReminder => 'ማስታወሻ ላክ';

  @override
  String reminderMessage(String name, String amount, String shopName) {
    return 'ሰላም $name፣ በ$shopName ያልተከፈለ የ$amount ብር ዱቤ እንዳለቦት በአክብሮት እናስታውሳለን። አመሰግናለሁ!';
  }

  @override
  String get customerDetail => 'የደንበኛ ዝርዝር';

  @override
  String get currentBalance => 'ወቅታዊ ቀሪ ሒሳብ';

  @override
  String get addCreditAction => '+ ዱቤ ጨምር';

  @override
  String get recordPaymentAction => 'ክፍያ መዝግብ';

  @override
  String get transactionHistory => 'የሒሳብ ታሪክ';

  @override
  String get noTransactionsCustomer => 'ለዚህ ደንበኛ እስካሁን የተመዘገበ ዝውውር የለም።';

  @override
  String get newCreditSaleTitle => 'አዲስ የዱቤ ሽያጭ';

  @override
  String get selectCustomer => 'ደንበኛ ይምረጡ';

  @override
  String get chooseCustomerHint => 'ደንበኛ ይምረጡ';

  @override
  String get saleAmount => 'የሽያጩ መጠን (ብር)';

  @override
  String get amountPlaceholder => '0.00';

  @override
  String get itemsNote => 'ዕቃዎች / ማስታወሻ (አማራጭ)';

  @override
  String get itemsNoteHint => 'ለምሳሌ፡ ስኳር 2 ኪሎ፣ ዘይት 1 ሊትር';

  @override
  String get transactionDate => 'ቀን እና ሰዓት';

  @override
  String get saveCreditSale => 'የዱቤ ሽያጩን መዝግብ';

  @override
  String get creditSaleSuccess => 'የዱቤ ሽያጭ ተመዝግቧል';

  @override
  String get invalidAmount => 'ከ 0 የሚበልጥ ትክክለኛ መጠን ያስገቡ';

  @override
  String get recordRepaymentTitle => 'የዱቤ ክፍያ መመዝገቢያ';

  @override
  String get paymentAmount => 'የክፍያው መጠን (ብር)';

  @override
  String currentDebtNotice(String balance) {
    return 'ያለበት ቀሪ ሒሳብ: $balance';
  }

  @override
  String get fullBalanceChip => 'ሙሉ ሒሳብ';

  @override
  String get paymentMethod => 'የክፍያ ዘዴ';

  @override
  String get methodCash => 'በጥሬ ገንዘብ';

  @override
  String get methodDigital => 'በዲጂታል (ቴሌብር/ባንክ)';

  @override
  String get digitalMethodNotice => 'ለመረጃ መመዝገቢያ ብቻ — የክፍያ መተግበሪያ አያያይዝም።';

  @override
  String get repaymentNote => 'ማስታወሻ / ደረሰኝ ቁጥር (አማራጭ)';

  @override
  String get repaymentNoteHint => 'ለምሳሌ፡ በቴሌብር፣ በሱቅ የተከፈለ';

  @override
  String get confirmRepayment => 'ክፍያውን አረጋግጥ';

  @override
  String get repaymentSuccess => 'ክፍያው ተመዝግቧል';

  @override
  String amountExceedsBalance(String balance) {
    return 'የክፍያው መጠን ካለበት ቀሪ ሒሳብ ($balance) መብለጥ አይችልም';
  }

  @override
  String get ledger => 'የሒሳብ መዝገብ';

  @override
  String get filterAllTransactions => 'ሁሉም';

  @override
  String get filterSales => 'ሽያጭ';

  @override
  String get filterRepayments => 'ክፍያዎች';

  @override
  String get transactionCredit => 'የዱቤ ሽያጭ';

  @override
  String get transactionPayment => 'የዱቤ ክፍያ';

  @override
  String get transactionReversal => 'ስረዛ (የተመለሰ)';

  @override
  String get reverseEntryAction => 'መዝገቡን ሰርዝ';

  @override
  String get reverseConfirmTitle => 'ይህን ዝውውር መሰረዝ ይፈልጋሉ?';

  @override
  String get reverseConfirmMessage =>
      'ይህ እርምጃ ሒሳቡን ለማስተካከል ቋሚ የስረዛ መዝገብ ይፈጥራል። ዋናው መዝገብ በታሪክ ውስጥ ይቀራል።';

  @override
  String get reversalSuccess => 'ዝውውሩ ተሰርዟል';

  @override
  String get alreadyReversed => 'ይህ ዝውውር አስቀድሞ ተሰርዟል';

  @override
  String get more => 'ተጨማሪ';

  @override
  String get shopProfile => 'የሱቅ መረጃ';

  @override
  String get defaultShopName => 'የሰፈር ሱቅ';

  @override
  String get deviceIdLabel => 'የመሳሪያው መለያ (Device ID)';

  @override
  String get languageSetting => 'ቋንቋ';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ (Amharic)';

  @override
  String get offlineAndSync => 'ከመስመር ውጭ እና ማመሳሰል';

  @override
  String get syncNow => 'አሁን አመሳስል';

  @override
  String get syncSuccess => 'ማመሳሰል በተሳካ ሁኔታ ተጠናቋል';

  @override
  String get syncInProgress => 'በማመሳሰል ላይ...';

  @override
  String unsyncedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ያልተመሳሰሉ መረጃዎች',
      one: '1 ያልተመሳሰለ መረጃ',
    );
    return '$_temp0';
  }

  @override
  String get allSyncedNotice => 'ሁሉም መረጃዎች ከዋናው ሰርቨር ጋር ተመሳስለዋል።';

  @override
  String get aboutAstawash => 'ስለ አስታዋሽ';

  @override
  String get appVersion => 'ስሪት 1.0.0';

  @override
  String get appDescription =>
      'አስታዋሽ ለኢትዮጵያ ሰፈር ሱቆች የተዘጋጀ ያለ ኢንተርኔት የሚሰራ የዱቤ ሒሳብ መመዝገቢያ ነው።';
}
