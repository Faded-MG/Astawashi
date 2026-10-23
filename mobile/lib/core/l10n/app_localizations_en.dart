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
  String get appTagline => 'Keep track. Grow together.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get search => 'Search';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'An error occurred';

  @override
  String get empty => 'No records found';

  @override
  String get birr => 'Birr';

  @override
  String get etb => 'ETB';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboardingTitle1 => 'Never lose track of credit';

  @override
  String get onboardingDesc1 =>
      'Record credit sales and repayments in seconds, even without an internet connection.';

  @override
  String get onboardingTitle2 => 'Friendly SMS reminders';

  @override
  String get onboardingDesc2 =>
      'Send polite and transparent payment reminders to your customers with a single tap.';

  @override
  String get onboardingTitle3 => '100% Offline-First';

  @override
  String get onboardingDesc3 =>
      'Your data stays safe on your device and syncs securely whenever you are online.';

  @override
  String get signIn => 'Sign In';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get signInSubtitle =>
      'Enter your phone number and 4-digit PIN to access your shop.';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneHint => '09XXXXXXXX';

  @override
  String get pin => '4-Digit PIN';

  @override
  String get pinHint => '••••';

  @override
  String get enterValidPhone => 'Please enter a valid Ethiopian phone number';

  @override
  String get enterValidPin => 'PIN must be 4 digits';

  @override
  String get continueOffline => 'Continue in Offline Mode';

  @override
  String get offlineShopNotice =>
      'Without signing in, records stay in a separate local-only shop and will not sync after you sign in.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get totalOutstanding => 'Total Outstanding';

  @override
  String customersWithBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers with balance',
      one: '1 customer with balance',
    );
    return '$_temp0';
  }

  @override
  String get newCreditSale => 'New Credit';

  @override
  String get recordRepayment => 'Repayment';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get viewAll => 'See all';

  @override
  String get noRecentActivity =>
      'No recent transactions. Record a sale to start.';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String syncStatusPending(int count) {
    return '$count Pending';
  }

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get customers => 'Customers';

  @override
  String get searchCustomersHint => 'Search by name or phone...';

  @override
  String get filterAll => 'All';

  @override
  String get filterWithBalance => 'With Balance';

  @override
  String get filterSettled => 'Settled';

  @override
  String get owesLabel => 'Owes';

  @override
  String get settledLabel => 'Settled';

  @override
  String get newCustomerTitle => 'Add New Customer';

  @override
  String get customerName => 'Customer Name';

  @override
  String get customerNameHint => 'e.g. Abebe Kebede';

  @override
  String get customerPhone => 'Phone Number (Optional)';

  @override
  String get customerNote => 'Note (Optional)';

  @override
  String get customerNoteHint => 'e.g. House #14, Green gate';

  @override
  String get saveCustomer => 'Save Customer';

  @override
  String get customerAddedSuccess => 'Customer added successfully';

  @override
  String get noCustomersFound => 'No customers found';

  @override
  String get callCustomer => 'Call';

  @override
  String get sendReminder => 'Send Reminder';

  @override
  String reminderMessage(String name, String amount, String shopName) {
    return 'Hello $name, this is a friendly reminder that you have an outstanding credit balance of ETB $amount at $shopName. Thank you!';
  }

  @override
  String get customerDetail => 'Customer Details';

  @override
  String get currentBalance => 'Current Balance';

  @override
  String get addCreditAction => '+ Add Credit';

  @override
  String get recordPaymentAction => 'Record Payment';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get noTransactionsCustomer =>
      'No transactions recorded for this customer yet.';

  @override
  String get newCreditSaleTitle => 'New Credit Sale';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get chooseCustomerHint => 'Choose a customer';

  @override
  String get saleAmount => 'Sale Amount (Birr)';

  @override
  String get amountPlaceholder => '0.00';

  @override
  String get itemsNote => 'Items / Notes (Optional)';

  @override
  String get itemsNoteHint => 'e.g. Sugar 2kg, Cooking oil 1L';

  @override
  String get transactionDate => 'Date & Time';

  @override
  String get saveCreditSale => 'Save Credit Sale';

  @override
  String get creditSaleSuccess => 'Credit sale recorded';

  @override
  String get invalidAmount => 'Please enter a valid amount greater than 0';

  @override
  String get recordRepaymentTitle => 'Record Repayment';

  @override
  String get paymentAmount => 'Payment Amount (Birr)';

  @override
  String currentDebtNotice(String balance) {
    return 'Current balance: $balance';
  }

  @override
  String get fullBalanceChip => 'Full Balance';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodDigital => 'Digital Payment';

  @override
  String get digitalMethodNotice =>
      'For record keeping only — no gateway integration.';

  @override
  String get repaymentNote => 'Reference / Note (Optional)';

  @override
  String get repaymentNoteHint => 'e.g. Paid at kiosk, Telebirr txn';

  @override
  String get confirmRepayment => 'Confirm Repayment';

  @override
  String get repaymentSuccess => 'Repayment recorded';

  @override
  String amountExceedsBalance(String balance) {
    return 'Payment amount cannot exceed outstanding balance of $balance';
  }

  @override
  String get ledger => 'Ledger';

  @override
  String get filterAllTransactions => 'All';

  @override
  String get filterSales => 'Sales';

  @override
  String get filterRepayments => 'Repayments';

  @override
  String get transactionCredit => 'Credit Sale';

  @override
  String get transactionPayment => 'Repayment';

  @override
  String get transactionReversal => 'Reversal';

  @override
  String get reverseEntryAction => 'Reverse Entry';

  @override
  String get reverseConfirmTitle => 'Reverse this transaction?';

  @override
  String get reverseConfirmMessage =>
      'This will add an immutable reversal entry to correct the balance. The original entry remains in the audit log.';

  @override
  String get reversalSuccess => 'Transaction reversed';

  @override
  String get alreadyReversed => 'This entry has already been reversed';

  @override
  String get more => 'More';

  @override
  String get shopProfile => 'Shop Profile';

  @override
  String get defaultShopName => 'Neighborhood Shop';

  @override
  String get deviceIdLabel => 'Device ID';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ (Amharic)';

  @override
  String get offlineAndSync => 'Offline & Synchronization';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncSuccess => 'Sync completed successfully';

  @override
  String get syncInProgress => 'Syncing...';

  @override
  String unsyncedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unsynced records',
      one: '1 unsynced record',
    );
    return '$_temp0';
  }

  @override
  String get allSyncedNotice => 'All records are synced with the server.';

  @override
  String get aboutAstawash => 'About Astawash';

  @override
  String get appVersion => 'Version 1.0.0';

  @override
  String get appDescription =>
      'Astawash is an offline-first digital credit ledger for Ethiopian neighborhood shops.';

  @override
  String get offlineDescription =>
      'Your local ledger stays available without internet. Sign in when you are online to synchronize account-scoped records.';

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
