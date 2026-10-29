// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SatsFarm';

  @override
  String get walletBalance => 'Wallet Balance';

  @override
  String get receive => 'Receive';

  @override
  String get send => 'Send';

  @override
  String get createGoal => 'Create Farm Goal';

  @override
  String get groupPot => 'Cooperative Esusu';

  @override
  String get onboardingTitle => 'Welcome to SatsFarm';

  @override
  String get createWallet => 'Create wallet';

  @override
  String get restoreWallet => 'Restore wallet';

  @override
  String get seasonGoals => 'Season goals';

  @override
  String get generateAddress => 'Generate receive address';

  @override
  String get generateInvoice => 'Generate Lightning invoice';

  @override
  String get nodeUnavailable => 'Lightning node is unavailable on this platform';

  @override
  String lightningStatus(String status) {
    return 'Lightning: $status';
  }

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get refreshBalance => 'Refresh balance';

  @override
  String get continueButton => 'Continue';

  @override
  String get phaseTwoGoalsPlaceholder => 'Phase 2: seasonal savings goals will appear here.';

  @override
  String get linuxWalletLimitation => 'Receive addresses work locally. Balance sync and Lightning need additional Linux native wallet support.';

  @override
  String get recoveryPhraseTitle => 'Back up your recovery phrase';

  @override
  String get recoveryPhraseWarning => 'Write these words down in order and keep them private. Anyone with this phrase can control this wallet. Do not save it in a screenshot or share it.';

  @override
  String get iSavedPhrase => 'I wrote down and safely stored these words';

  @override
  String get continueToWallet => 'Continue to wallet';

  @override
  String get loadingWallet => 'Checking for a saved wallet…';

  @override
  String get retry => 'Retry';

  @override
  String get secureStorageUnavailable => 'SatsFarm could not read this device\'s secure wallet storage. Retry, and do not clear app data or uninstall unless your recovery phrase is safely backed up.';

  @override
  String get greeting => 'Assalamu alaikum';

  @override
  String get locationNorthernNigeria => 'NORTHERN NIGERIA';

  @override
  String get seasonLabel => '2026 FARMING SEASON';

  @override
  String get walletIntro => 'Your money, ready for the season.';

  @override
  String get availableBalance => 'AVAILABLE BALANCE';

  @override
  String get ngnEstimateLabel => 'Approximate NGN value · demo rate';

  @override
  String get mutinynetDemo => 'MUTINYNET DEMO';

  @override
  String get fieldAndSeason => 'FARM SEASON';

  @override
  String get seasonCardTitle => 'Plan for a stronger harvest';

  @override
  String get seasonCardBody => 'Set a savings target for seeds, fertilizer, or harvest costs.';

  @override
  String get startPlanning => 'Start planning';

  @override
  String get activityTitle => 'Wallet activity';

  @override
  String get activityEmpty => 'Your activity will appear here when wallet sync is available.';

  @override
  String get walletSecurityTitle => 'Your wallet. Your control.';

  @override
  String get walletSecurityBody => 'Your recovery phrase stays with you. SatsFarm cannot reset or access it.';

  @override
  String get onboardingBody => 'A simple Bitcoin wallet for farm savings and payments.';

  @override
  String get onboardingNote => 'Start with a test wallet. Never use real Bitcoin in this demo.';

  @override
  String get receiveOnchainTitle => 'On-chain address';

  @override
  String get receiveOnchainBody => 'Share this address to receive Mutinynet test bitcoin.';

  @override
  String get receiveLightningTitle => 'Lightning invoice';

  @override
  String get receiveLightningBody => 'Create an invoice for a fast Lightning payment.';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get addressCopied => 'Address copied';

  @override
  String get networkNoticeTitle => 'Mutinynet test network';

  @override
  String get networkNoticeBody => 'Test coins have no value. This Linux build can create addresses, but cannot sync payments yet.';

  @override
  String get phaseTwo => 'COMING IN PHASE 2';

  @override
  String get cancel => 'Cancel';

  @override
  String get myVouchers => 'My vouchers';

  @override
  String get voucherEmpty => 'No vouchers yet. The SatsFarm desk will send input support here.';

  @override
  String get voucherRefresh => 'Refresh from program desk';

  @override
  String get vouchersGrantTotal => 'GRANT BALANCE TO SPEND';

  @override
  String get vouchersSubcopy => 'Input support from the SatsFarm desk. Spend it at approved dealers.';

  @override
  String get voucherKindGrant => 'GRANT';

  @override
  String get voucherKindLoan => 'LOAN';

  @override
  String get voucherStatusActive => 'ACTIVE';

  @override
  String get voucherStatusSpent => 'SPENT';

  @override
  String get voucherStatusClosed => 'CLOSED';

  @override
  String voucherIssuedAmount(String amount) {
    return '$amount issued';
  }

  @override
  String voucherAmountOwed(String amount) {
    return 'Amount owed: $amount';
  }

  @override
  String get voucherRedeem => 'Redeem at dealer';

  @override
  String get voucherRedeemHint => 'Paste the dealer\'s BOLT11 invoice';

  @override
  String get voucherScanInvoice => 'Scan dealer QR code';

  @override
  String get voucherScanTitle => 'Scan dealer invoice';

  @override
  String get voucherScanHint => 'Hold the dealer\'s Mutinynet payment QR code inside the frame.';

  @override
  String get voucherQrInvalid => 'That QR code is not a valid Lightning invoice. Scan the dealer\'s payment QR.';

  @override
  String get voucherRedeemSubmit => 'Pay dealer';

  @override
  String get voucherRateLabel => 'Demo rate: 5 naira per sat. Mutinynet is a test network.';

  @override
  String get voucherPayingNow => 'Paying the dealer invoice…';

  @override
  String get redeemSettled => 'Dealer paid on Mutinynet';

  @override
  String get redeemStillPending => 'Payment is still settling…';

  @override
  String get redeemStillPendingBody => 'The program desk is paying the dealer over Lightning. Check again in a moment.';

  @override
  String get redeemFailed => 'Payment failed';

  @override
  String get redeemFailedBody => 'The desk could not pay this invoice. No voucher balance was spent. Please confirm the invoice with the dealer.';

  @override
  String get voucherRegisterTitle => 'Claim your program profile';

  @override
  String get voucherRegisterBody => 'Register once to receive vouchers and pay dealers directly from them.';

  @override
  String get voucherNameLabel => 'Full name';

  @override
  String get voucherLocationLabel => 'Village or town';

  @override
  String get voucherRegisterAction => 'Join the program';

  @override
  String get inviteJoinTitle => 'Join SatsFarm';

  @override
  String get inviteJoinBody => 'Enter the one-time invite code from your program officer, or scan their QR code.';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get inviteScanAction => 'Scan QR code';

  @override
  String get inviteSubmitAction => 'Join my program';

  @override
  String get inviteInvalidCode => 'That code is not valid. Check it and try again.';

  @override
  String get inviteExpiredCode => 'This code has expired. Ask your program officer for a new one.';

  @override
  String get inviteUsedCode => 'This code has already been used on another device. Ask your program officer for a new code.';

  @override
  String get inviteUnavailable => 'Could not connect to SatsFarm. Check your connection and try again.';

  @override
  String get inviteStorageError => 'SatsFarm could not save your secure sign-in on this device. Please try again.';

  @override
  String get farmerBalanceLabel => 'SUPPORT BALANCE';

  @override
  String get farmerHistoryLabel => 'Support history';

  @override
  String get farmerHistoryEmpty => 'Your support history will appear here.';

  @override
  String get farmerRepaymentLabel => 'Repayment';

  @override
  String get repaymentTypeGrain => 'Grain';

  @override
  String get repaymentTypeCash => 'Cash';

  @override
  String get repaymentTypeTransfer => 'Transfer';

  @override
  String get farmerNoteLabel => 'Note';

  @override
  String get switchFarmer => 'Switch farmer';

  @override
  String get switchFarmerTitle => 'Switch farmer account?';

  @override
  String get switchFarmerConfirm => 'This signs out this farmer on this device. Your wallet and wallet recovery phrase will not be changed.';

  @override
  String get farmerWalletAction => 'My wallet';

  @override
  String get farmerRefreshAction => 'Refresh balance';

  @override
  String farmerWelcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get farmerSupportLabel => 'Program support';

  @override
  String get inviteCameraTitle => 'Scan your invite';

  @override
  String get inviteCameraHint => 'Hold the dashboard QR code inside the frame.';

  @override
  String get inviteTestNetworkBody => 'SatsFarm is using Mutinynet, a Bitcoin test network. Test coins have no cash value.';

  @override
  String get checkingFarmerSession => 'Checking your SatsFarm sign-in…';
}
