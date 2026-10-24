import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
  ];

  /// App title
  ///
  /// In en, this message translates to:
  /// **'Astawash'**
  String get appTitle;

  /// App tagline
  ///
  /// In en, this message translates to:
  /// **'Keep track. Grow together.'**
  String get appTagline;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get empty;

  /// No description provided for @birr.
  ///
  /// In en, this message translates to:
  /// **'Birr'**
  String get birr;

  /// No description provided for @etb.
  ///
  /// In en, this message translates to:
  /// **'ETB'**
  String get etb;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Never lose track of credit'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Record credit sales and repayments in seconds, even without an internet connection.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Friendly SMS reminders'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Send polite and transparent payment reminders to your customers with a single tap.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'100% Offline-First'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Your data stays safe on your device and syncs securely whenever you are online.'**
  String get onboardingDesc3;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number and 4-digit PIN to access your shop.'**
  String get signInSubtitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'09XXXXXXXX'**
  String get phoneHint;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'4-Digit PIN'**
  String get pin;

  /// No description provided for @pinHint.
  ///
  /// In en, this message translates to:
  /// **'••••'**
  String get pinHint;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Ethiopian phone number'**
  String get enterValidPhone;

  /// No description provided for @enterValidPin.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 digits'**
  String get enterValidPin;

  /// No description provided for @continueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue in Offline Mode'**
  String get continueOffline;

  /// No description provided for @offlineShopNotice.
  ///
  /// In en, this message translates to:
  /// **'Without signing in, records stay in a separate local-only shop and will not sync after you sign in.'**
  String get offlineShopNotice;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @totalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding'**
  String get totalOutstanding;

  /// No description provided for @customersWithBalance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer with balance} other{{count} customers with balance}}'**
  String customersWithBalance(int count);

  /// No description provided for @newCreditSale.
  ///
  /// In en, this message translates to:
  /// **'New Credit'**
  String get newCreditSale;

  /// No description provided for @recordRepayment.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get recordRepayment;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get viewAll;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent transactions. Record a sale to start.'**
  String get noRecentActivity;

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'{count} Pending'**
  String syncStatusPending(int count);

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncStatusOffline;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @searchCustomersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get searchCustomersHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterWithBalance.
  ///
  /// In en, this message translates to:
  /// **'With Balance'**
  String get filterWithBalance;

  /// No description provided for @filterSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get filterSettled;

  /// No description provided for @owesLabel.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get owesLabel;

  /// No description provided for @settledLabel.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settledLabel;

  /// No description provided for @newCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Customer'**
  String get newCustomerTitle;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @customerNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Abebe Kebede'**
  String get customerNameHint;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Optional)'**
  String get customerPhone;

  /// No description provided for @customerNote.
  ///
  /// In en, this message translates to:
  /// **'Note (Optional)'**
  String get customerNote;

  /// No description provided for @customerNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. House #14, Green gate'**
  String get customerNoteHint;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save Customer'**
  String get saveCustomer;

  /// No description provided for @customerAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Customer added successfully'**
  String get customerAddedSuccess;

  /// No description provided for @noCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomersFound;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callCustomer;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @reminderMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, this is a friendly reminder that you have an outstanding credit balance of ETB {amount} at {shopName}. Thank you!'**
  String reminderMessage(String name, String amount, String shopName);

  /// No description provided for @customerDetail.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetail;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @addCreditAction.
  ///
  /// In en, this message translates to:
  /// **'+ Add Credit'**
  String get addCreditAction;

  /// No description provided for @recordPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentAction;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @noTransactionsCustomer.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded for this customer yet.'**
  String get noTransactionsCustomer;

  /// No description provided for @newCreditSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'New Credit Sale'**
  String get newCreditSaleTitle;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @chooseCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer'**
  String get chooseCustomerHint;

  /// No description provided for @saleAmount.
  ///
  /// In en, this message translates to:
  /// **'Sale Amount (Birr)'**
  String get saleAmount;

  /// No description provided for @amountPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get amountPlaceholder;

  /// No description provided for @itemsNote.
  ///
  /// In en, this message translates to:
  /// **'Items / Notes (Optional)'**
  String get itemsNote;

  /// No description provided for @itemsNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sugar 2kg, Cooking oil 1L'**
  String get itemsNoteHint;

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get transactionDate;

  /// No description provided for @saveCreditSale.
  ///
  /// In en, this message translates to:
  /// **'Save Credit Sale'**
  String get saveCreditSale;

  /// No description provided for @creditSaleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Credit sale recorded'**
  String get creditSaleSuccess;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount greater than 0'**
  String get invalidAmount;

  /// No description provided for @recordRepaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Repayment'**
  String get recordRepaymentTitle;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment Amount (Birr)'**
  String get paymentAmount;

  /// No description provided for @currentDebtNotice.
  ///
  /// In en, this message translates to:
  /// **'Current balance: {balance}'**
  String currentDebtNotice(String balance);

  /// No description provided for @fullBalanceChip.
  ///
  /// In en, this message translates to:
  /// **'Full Balance'**
  String get fullBalanceChip;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital Payment'**
  String get methodDigital;

  /// No description provided for @digitalMethodNotice.
  ///
  /// In en, this message translates to:
  /// **'For record keeping only — no gateway integration.'**
  String get digitalMethodNotice;

  /// No description provided for @repaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Reference / Note (Optional)'**
  String get repaymentNote;

  /// No description provided for @repaymentNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Paid at kiosk, Telebirr txn'**
  String get repaymentNoteHint;

  /// No description provided for @confirmRepayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Repayment'**
  String get confirmRepayment;

  /// No description provided for @repaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Repayment recorded'**
  String get repaymentSuccess;

  /// No description provided for @amountExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment amount cannot exceed outstanding balance of {balance}'**
  String amountExceedsBalance(String balance);

  /// No description provided for @ledger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledger;

  /// No description provided for @filterAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllTransactions;

  /// No description provided for @filterSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get filterSales;

  /// No description provided for @filterRepayments.
  ///
  /// In en, this message translates to:
  /// **'Repayments'**
  String get filterRepayments;

  /// No description provided for @transactionCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale'**
  String get transactionCredit;

  /// No description provided for @transactionPayment.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get transactionPayment;

  /// No description provided for @transactionReversal.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get transactionReversal;

  /// No description provided for @reverseEntryAction.
  ///
  /// In en, this message translates to:
  /// **'Reverse Entry'**
  String get reverseEntryAction;

  /// No description provided for @reverseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse this transaction?'**
  String get reverseConfirmTitle;

  /// No description provided for @reverseConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will add an immutable reversal entry to correct the balance. The original entry remains in the audit log.'**
  String get reverseConfirmMessage;

  /// No description provided for @reversalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transaction reversed'**
  String get reversalSuccess;

  /// No description provided for @alreadyReversed.
  ///
  /// In en, this message translates to:
  /// **'This entry has already been reversed'**
  String get alreadyReversed;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @shopProfile.
  ///
  /// In en, this message translates to:
  /// **'Shop Profile'**
  String get shopProfile;

  /// No description provided for @defaultShopName.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood Shop'**
  String get defaultShopName;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @languageSetting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSetting;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageAmharic.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ (Amharic)'**
  String get languageAmharic;

  /// No description provided for @offlineAndSync.
  ///
  /// In en, this message translates to:
  /// **'Offline & Synchronization'**
  String get offlineAndSync;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed successfully'**
  String get syncSuccess;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncInProgress;

  /// No description provided for @unsyncedEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unsynced record} other{{count} unsynced records}}'**
  String unsyncedEntries(int count);

  /// No description provided for @allSyncedNotice.
  ///
  /// In en, this message translates to:
  /// **'All records are synced with the server.'**
  String get allSyncedNotice;

  /// No description provided for @aboutAstawash.
  ///
  /// In en, this message translates to:
  /// **'About Astawash'**
  String get aboutAstawash;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get appVersion;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Astawash is an offline-first digital credit ledger for Ethiopian neighborhood shops.'**
  String get appDescription;

  /// No description provided for @offlineDescription.
  ///
  /// In en, this message translates to:
  /// **'Your local ledger stays available without internet. Sign in when you are online to synchronize account-scoped records.'**
  String get offlineDescription;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name (optional)'**
  String get shopNameLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create shop account'**
  String get registerButton;

  /// No description provided for @syncButton.
  ///
  /// In en, this message translates to:
  /// **'Synchronize now'**
  String get syncButton;

  /// No description provided for @syncIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready to synchronize'**
  String get syncIdle;

  /// No description provided for @syncSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Synchronization complete'**
  String get syncSucceeded;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Synchronization failed. Local records are still saved.'**
  String get syncFailed;

  /// No description provided for @authenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to synchronize. Local records remain on this device.'**
  String get authenticationRequired;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authenticationFailed;

  /// No description provided for @syncResult.
  ///
  /// In en, this message translates to:
  /// **'Sent {customers} customers and {entries} ledger entries.'**
  String syncResult(int customers, int entries);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out? Your local records will remain safe on this device.'**
  String get logoutConfirmMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
