import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ha.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ha')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SatsFarm'**
  String get appTitle;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @createGoal.
  ///
  /// In en, this message translates to:
  /// **'Create Farm Goal'**
  String get createGoal;

  /// No description provided for @groupPot.
  ///
  /// In en, this message translates to:
  /// **'Cooperative Esusu'**
  String get groupPot;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to SatsFarm'**
  String get onboardingTitle;

  /// No description provided for @createWallet.
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get createWallet;

  /// No description provided for @restoreWallet.
  ///
  /// In en, this message translates to:
  /// **'Restore wallet'**
  String get restoreWallet;

  /// No description provided for @seasonGoals.
  ///
  /// In en, this message translates to:
  /// **'Season goals'**
  String get seasonGoals;

  /// No description provided for @generateAddress.
  ///
  /// In en, this message translates to:
  /// **'Generate receive address'**
  String get generateAddress;

  /// No description provided for @generateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Generate Lightning invoice'**
  String get generateInvoice;

  /// No description provided for @nodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Lightning node is unavailable on this platform'**
  String get nodeUnavailable;

  /// No description provided for @lightningStatus.
  ///
  /// In en, this message translates to:
  /// **'Lightning: {status}'**
  String lightningStatus(String status);

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @refreshBalance.
  ///
  /// In en, this message translates to:
  /// **'Refresh balance'**
  String get refreshBalance;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @phaseTwoGoalsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Phase 2: seasonal savings goals will appear here.'**
  String get phaseTwoGoalsPlaceholder;

  /// No description provided for @linuxWalletLimitation.
  ///
  /// In en, this message translates to:
  /// **'Receive addresses work locally. Balance sync and Lightning need additional Linux native wallet support.'**
  String get linuxWalletLimitation;

  /// No description provided for @recoveryPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your recovery phrase'**
  String get recoveryPhraseTitle;

  /// No description provided for @recoveryPhraseWarning.
  ///
  /// In en, this message translates to:
  /// **'Write these words down in order and keep them private. Anyone with this phrase can control this wallet. Do not save it in a screenshot or share it.'**
  String get recoveryPhraseWarning;

  /// No description provided for @iSavedPhrase.
  ///
  /// In en, this message translates to:
  /// **'I wrote down and safely stored these words'**
  String get iSavedPhrase;

  /// No description provided for @continueToWallet.
  ///
  /// In en, this message translates to:
  /// **'Continue to wallet'**
  String get continueToWallet;

  /// No description provided for @loadingWallet.
  ///
  /// In en, this message translates to:
  /// **'Checking for a saved wallet…'**
  String get loadingWallet;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @secureStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SatsFarm could not read this device\'s secure wallet storage. Retry, and do not clear app data or uninstall unless your recovery phrase is safely backed up.'**
  String get secureStorageUnavailable;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Assalamu alaikum'**
  String get greeting;

  /// No description provided for @locationNorthernNigeria.
  ///
  /// In en, this message translates to:
  /// **'NORTHERN NIGERIA'**
  String get locationNorthernNigeria;

  /// No description provided for @seasonLabel.
  ///
  /// In en, this message translates to:
  /// **'2026 FARMING SEASON'**
  String get seasonLabel;

  /// No description provided for @walletIntro.
  ///
  /// In en, this message translates to:
  /// **'Your money, ready for the season.'**
  String get walletIntro;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE BALANCE'**
  String get availableBalance;

  /// No description provided for @ngnEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Approximate NGN value · demo rate'**
  String get ngnEstimateLabel;

  /// No description provided for @mutinynetDemo.
  ///
  /// In en, this message translates to:
  /// **'MUTINYNET DEMO'**
  String get mutinynetDemo;

  /// No description provided for @fieldAndSeason.
  ///
  /// In en, this message translates to:
  /// **'FARM SEASON'**
  String get fieldAndSeason;

  /// No description provided for @seasonCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan for a stronger harvest'**
  String get seasonCardTitle;

  /// No description provided for @seasonCardBody.
  ///
  /// In en, this message translates to:
  /// **'Set a savings target for seeds, fertilizer, or harvest costs.'**
  String get seasonCardBody;

  /// No description provided for @startPlanning.
  ///
  /// In en, this message translates to:
  /// **'Start planning'**
  String get startPlanning;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet activity'**
  String get activityTitle;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your activity will appear here when wallet sync is available.'**
  String get activityEmpty;

  /// No description provided for @walletSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallet. Your control.'**
  String get walletSecurityTitle;

  /// No description provided for @walletSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase stays with you. SatsFarm cannot reset or access it.'**
  String get walletSecurityBody;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'A simple Bitcoin wallet for farm savings and payments.'**
  String get onboardingBody;

  /// No description provided for @onboardingNote.
  ///
  /// In en, this message translates to:
  /// **'Start with a test wallet. Never use real Bitcoin in this demo.'**
  String get onboardingNote;

  /// No description provided for @receiveOnchainTitle.
  ///
  /// In en, this message translates to:
  /// **'On-chain address'**
  String get receiveOnchainTitle;

  /// No description provided for @receiveOnchainBody.
  ///
  /// In en, this message translates to:
  /// **'Share this address to receive Mutinynet test bitcoin.'**
  String get receiveOnchainBody;

  /// No description provided for @receiveLightningTitle.
  ///
  /// In en, this message translates to:
  /// **'Lightning invoice'**
  String get receiveLightningTitle;

  /// No description provided for @receiveLightningBody.
  ///
  /// In en, this message translates to:
  /// **'Create an invoice for a fast Lightning payment.'**
  String get receiveLightningBody;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get addressCopied;

  /// No description provided for @networkNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mutinynet test network'**
  String get networkNoticeTitle;

  /// No description provided for @networkNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Test coins have no value. This Linux build can create addresses, but cannot sync payments yet.'**
  String get networkNoticeBody;

  /// No description provided for @phaseTwo.
  ///
  /// In en, this message translates to:
  /// **'COMING IN PHASE 2'**
  String get phaseTwo;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @myVouchers.
  ///
  /// In en, this message translates to:
  /// **'My vouchers'**
  String get myVouchers;

  /// No description provided for @voucherEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vouchers yet. The SatsFarm desk will send input support here.'**
  String get voucherEmpty;

  /// No description provided for @voucherRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh from program desk'**
  String get voucherRefresh;

  /// No description provided for @vouchersGrantTotal.
  ///
  /// In en, this message translates to:
  /// **'GRANT BALANCE TO SPEND'**
  String get vouchersGrantTotal;

  /// No description provided for @vouchersSubcopy.
  ///
  /// In en, this message translates to:
  /// **'Input support from the SatsFarm desk. Spend it at approved dealers.'**
  String get vouchersSubcopy;

  /// No description provided for @voucherKindGrant.
  ///
  /// In en, this message translates to:
  /// **'GRANT'**
  String get voucherKindGrant;

  /// No description provided for @voucherKindLoan.
  ///
  /// In en, this message translates to:
  /// **'LOAN'**
  String get voucherKindLoan;

  /// No description provided for @voucherStatusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get voucherStatusActive;

  /// No description provided for @voucherStatusSpent.
  ///
  /// In en, this message translates to:
  /// **'SPENT'**
  String get voucherStatusSpent;

  /// No description provided for @voucherStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get voucherStatusClosed;

  /// No description provided for @voucherIssuedAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} issued'**
  String voucherIssuedAmount(String amount);

  /// No description provided for @voucherAmountOwed.
  ///
  /// In en, this message translates to:
  /// **'Amount owed: {amount}'**
  String voucherAmountOwed(String amount);

  /// No description provided for @voucherRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem at dealer'**
  String get voucherRedeem;

  /// No description provided for @voucherRedeemHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the dealer\'s BOLT11 invoice'**
  String get voucherRedeemHint;

  /// No description provided for @voucherScanInvoice.
  ///
  /// In en, this message translates to:
  /// **'Scan dealer QR code'**
  String get voucherScanInvoice;

  /// No description provided for @voucherScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan dealer invoice'**
  String get voucherScanTitle;

  /// No description provided for @voucherScanHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the dealer\'s Mutinynet payment QR code inside the frame.'**
  String get voucherScanHint;

  /// No description provided for @voucherQrInvalid.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a valid Lightning invoice. Scan the dealer\'s payment QR.'**
  String get voucherQrInvalid;

  /// No description provided for @voucherRedeemSubmit.
  ///
  /// In en, this message translates to:
  /// **'Pay dealer'**
  String get voucherRedeemSubmit;

  /// No description provided for @voucherRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo rate: 5 naira per sat. Mutinynet is a test network.'**
  String get voucherRateLabel;

  /// No description provided for @voucherPayingNow.
  ///
  /// In en, this message translates to:
  /// **'Paying the dealer invoice…'**
  String get voucherPayingNow;

  /// No description provided for @redeemSettled.
  ///
  /// In en, this message translates to:
  /// **'Dealer paid on Mutinynet'**
  String get redeemSettled;

  /// No description provided for @redeemStillPending.
  ///
  /// In en, this message translates to:
  /// **'Payment is still settling…'**
  String get redeemStillPending;

  /// No description provided for @redeemStillPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The program desk is paying the dealer over Lightning. Check again in a moment.'**
  String get redeemStillPendingBody;

  /// No description provided for @redeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get redeemFailed;

  /// No description provided for @redeemFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The desk could not pay this invoice. No voucher balance was spent. Please confirm the invoice with the dealer.'**
  String get redeemFailedBody;

  /// No description provided for @voucherRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim your program profile'**
  String get voucherRegisterTitle;

  /// No description provided for @voucherRegisterBody.
  ///
  /// In en, this message translates to:
  /// **'Register once to receive vouchers and pay dealers directly from them.'**
  String get voucherRegisterBody;

  /// No description provided for @voucherNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get voucherNameLabel;

  /// No description provided for @voucherLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Village or town'**
  String get voucherLocationLabel;

  /// No description provided for @voucherRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Join the program'**
  String get voucherRegisterAction;

  /// No description provided for @inviteJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join SatsFarm'**
  String get inviteJoinTitle;

  /// No description provided for @inviteJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the one-time invite code from your program officer, or scan their QR code.'**
  String get inviteJoinBody;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteScanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get inviteScanAction;

  /// No description provided for @inviteSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Join my program'**
  String get inviteSubmitAction;

  /// No description provided for @inviteInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not valid. Check it and try again.'**
  String get inviteInvalidCode;

  /// No description provided for @inviteExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Ask your program officer for a new one.'**
  String get inviteExpiredCode;

  /// No description provided for @inviteUsedCode.
  ///
  /// In en, this message translates to:
  /// **'This code has already been used on another device. Ask your program officer for a new code.'**
  String get inviteUsedCode;

  /// No description provided for @inviteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to SatsFarm. Check your connection and try again.'**
  String get inviteUnavailable;

  /// No description provided for @inviteStorageError.
  ///
  /// In en, this message translates to:
  /// **'SatsFarm could not save your secure sign-in on this device. Please try again.'**
  String get inviteStorageError;

  /// No description provided for @farmerBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT BALANCE'**
  String get farmerBalanceLabel;

  /// No description provided for @farmerHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Support history'**
  String get farmerHistoryLabel;

  /// No description provided for @farmerHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your support history will appear here.'**
  String get farmerHistoryEmpty;

  /// No description provided for @farmerRepaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get farmerRepaymentLabel;

  /// No description provided for @repaymentTypeGrain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get repaymentTypeGrain;

  /// No description provided for @repaymentTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get repaymentTypeCash;

  /// No description provided for @repaymentTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get repaymentTypeTransfer;

  /// No description provided for @farmerNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get farmerNoteLabel;

  /// No description provided for @switchFarmer.
  ///
  /// In en, this message translates to:
  /// **'Switch farmer'**
  String get switchFarmer;

  /// No description provided for @switchFarmerTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch farmer account?'**
  String get switchFarmerTitle;

  /// No description provided for @switchFarmerConfirm.
  ///
  /// In en, this message translates to:
  /// **'This signs out this farmer on this device. Your wallet and wallet recovery phrase will not be changed.'**
  String get switchFarmerConfirm;

  /// No description provided for @farmerWalletAction.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get farmerWalletAction;

  /// No description provided for @farmerRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh balance'**
  String get farmerRefreshAction;

  /// No description provided for @farmerWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String farmerWelcome(String name);

  /// No description provided for @farmerSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Program support'**
  String get farmerSupportLabel;

  /// No description provided for @inviteCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your invite'**
  String get inviteCameraTitle;

  /// No description provided for @inviteCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the dashboard QR code inside the frame.'**
  String get inviteCameraHint;

  /// No description provided for @inviteTestNetworkBody.
  ///
  /// In en, this message translates to:
  /// **'SatsFarm is using Mutinynet, a Bitcoin test network. Test coins have no cash value.'**
  String get inviteTestNetworkBody;

  /// No description provided for @checkingFarmerSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your SatsFarm sign-in…'**
  String get checkingFarmerSession;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ha'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ha': return AppLocalizationsHa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
