// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hausa (`ha`).
class AppLocalizationsHa extends AppLocalizations {
  AppLocalizationsHa([String locale = 'ha']) : super(locale);

  @override
  String get appTitle => 'SatsFarm';

  @override
  String get walletBalance => 'Adugan Guje';

  @override
  String get receive => 'Karba';

  @override
  String get send => 'Aika';

  @override
  String get createGoal => 'Kirkiro Manufar Noma';

  @override
  String get groupPot => 'Adashin Tarrayya';

  @override
  String get onboardingTitle => 'Barka da zuwa SatsFarm';

  @override
  String get createWallet => 'Kirkiri walat';

  @override
  String get restoreWallet => 'Mayar da walat';

  @override
  String get seasonGoals => 'Manufofin kakar noma';

  @override
  String get generateAddress => 'Samar da adireshin karba';

  @override
  String get generateInvoice => 'Samar da takardar biyan Lightning';

  @override
  String get nodeUnavailable => 'Ba a samun Lightning node a wannan dandali';

  @override
  String lightningStatus(String status) {
    return 'Lightning: $status';
  }

  @override
  String get running => 'Yana aiki';

  @override
  String get stopped => 'A tsaye';

  @override
  String get refreshBalance => 'Sabunta ma\'auni';

  @override
  String get continueButton => 'Ci gaba';

  @override
  String get phaseTwoGoalsPlaceholder => 'Manufofin ajiya na kakar noma za su bayyana a nan a kashi na biyu.';

  @override
  String get linuxWalletLimitation => 'Adireshin karba yana aiki a nan. Sabunta ma\'auni da Lightning suna bukatar tallafin Linux na musamman.';

  @override
  String get recoveryPhraseTitle => 'Ajiye kalmomin dawo da walat';

  @override
  String get recoveryPhraseWarning => 'Rubuta kalmomin nan a jere kuma ka boye su. Duk wanda ya mallaki kalmomin zai iya sarrafa walat din. Kada ka dauki hotonsu ko ka raba su.';

  @override
  String get iSavedPhrase => 'Na rubuta kalmomin kuma na adana su lafiya';

  @override
  String get continueToWallet => 'Ci gaba zuwa walat';

  @override
  String get loadingWallet => 'Ana duba ko akwai walat da aka adana…';

  @override
  String get retry => 'Sake gwadawa';

  @override
  String get secureStorageUnavailable => 'SatsFarm bai iya karanta amintaccen ajiyar walat na wannan na\'ura ba. Sake gwadawa, kuma kada ka goge bayanan manhaja ko ka cire ta sai kalmomin dawo da walat sun adana lafiya.';

  @override
  String get greeting => 'Assalamu alaikum';

  @override
  String get locationNorthernNigeria => 'AREWACIN NAJERIYA';

  @override
  String get seasonLabel => 'LOKACIN NOMA NA 2026';

  @override
  String get walletIntro => 'Kuɗinka a shirye don lokacin noma.';

  @override
  String get availableBalance => 'KUƊIN DA KE SAMU';

  @override
  String get ngnEstimateLabel => 'Kimanin darajar Naira · gwaji ne';

  @override
  String get mutinynetDemo => 'GWADAWAR MUTINYNET';

  @override
  String get fieldAndSeason => 'LOKACIN NOMA';

  @override
  String get seasonCardTitle => 'Shirya girbi mai albarka';

  @override
  String get seasonCardBody => 'Ƙirƙiri burin ajiya don iri, taki, ko kuɗin girbi.';

  @override
  String get startPlanning => 'Fara shiri';

  @override
  String get activityTitle => 'Ayyukan walat';

  @override
  String get activityEmpty => 'Ayyukanka za su bayyana nan idan daidaita walat ya samu.';

  @override
  String get walletSecurityTitle => 'Walat ɗinka. Ikonka.';

  @override
  String get walletSecurityBody => 'Kalmomin dawo da walat naka ne. SatsFarm ba zai iya canza su ko shiga walat ɗinka ba.';

  @override
  String get onboardingBody => 'Walat ɗin Bitcoin mai sauƙi don ajiyar noma da biyan kuɗi.';

  @override
  String get onboardingNote => 'Fara da walat ɗin gwaji. Kada ka yi amfani da Bitcoin na gaske a wannan gwaji.';

  @override
  String get receiveOnchainTitle => 'Adireshin kan sarka';

  @override
  String get receiveOnchainBody => 'Raba wannan adireshin don karɓar Bitcoin na gwajin Mutinynet.';

  @override
  String get receiveLightningTitle => 'Takardar biyan Lightning';

  @override
  String get receiveLightningBody => 'Ƙirƙiri takardar karɓar kuɗi ta Lightning cikin sauri.';

  @override
  String get copyAddress => 'Kwafi adireshi';

  @override
  String get addressCopied => 'An kwafi adireshi';

  @override
  String get networkNoticeTitle => 'Cibiyar gwajin Mutinynet';

  @override
  String get networkNoticeBody => 'Kuɗin gwaji ba su da darajar kuɗi. Wannan sigar Linux tana ƙirƙirar adireshi, amma ba ta iya daidaita biyan kuɗi tukuna.';

  @override
  String get phaseTwo => 'ZAI ZO A KASHI NA 2';

  @override
  String get cancel => 'Soke';

  @override
  String get myVouchers => 'Kuponai na';

  @override
  String get voucherEmpty => 'Babu kuponai tukuna. Ofishin SatsFarm za su turo tallafin shigo da kaya nan.';

  @override
  String get voucherRefresh => 'Sabunta daga ofishin shiri';

  @override
  String get vouchersGrantTotal => 'KUDIN KYAUTA DA ZA A AMFANI';

  @override
  String get vouchersSubcopy => 'Tallafin shigo da kaya daga ofishin SatsFarm. Ku yi amfani da shi a hannun \'yan kasuwa masu amincewa.';

  @override
  String get voucherKindGrant => 'KYAUTA';

  @override
  String get voucherKindLoan => 'RASHI';

  @override
  String get voucherStatusActive => 'YANA AIKI';

  @override
  String get voucherStatusSpent => 'AN CI';

  @override
  String get voucherStatusClosed => 'AN RUFE';

  @override
  String voucherIssuedAmount(String amount) {
    return 'An bayar da $amount';
  }

  @override
  String voucherAmountOwed(String amount) {
    return 'Adadin da ake bi: $amount';
  }

  @override
  String get voucherRedeem => 'Yi amfani a shagon';

  @override
  String get voucherRedeemHint => 'Liƙa kudin biyan BOLT11 na shagon';

  @override
  String get voucherScanInvoice => 'Duba lambar QR ta shagon';

  @override
  String get voucherScanTitle => 'Duba takardar biyan shagon';

  @override
  String get voucherScanHint => 'Sanya lambar QR ta biyan Mutinynet ta shagon a cikin firam.';

  @override
  String get voucherQrInvalid => 'Wannan lambar QR ba takardar biyan Lightning ba ce. Duba lambar QR ta biyan shagon.';

  @override
  String get voucherRedeemSubmit => 'Biya shagon';

  @override
  String get voucherRateLabel => 'Farashin misali: naira 5 a kowace sat. Mutinynet cibiyar gwaji ce.';

  @override
  String get voucherPayingNow => 'Ana biyan kudin shagon…';

  @override
  String get redeemSettled => 'An biya shagon a Mutinynet';

  @override
  String get redeemStillPending => 'Biyan yana matsawa tukuna…';

  @override
  String get redeemStillPendingBody => 'Ofishin shiri yana biya shagon ta Lightning. Duba sake a dan kadan.';

  @override
  String get redeemFailed => 'Biyan ya kasa';

  @override
  String get redeemFailedBody => 'Ofishin bai iya biyan wannan kudin ba. Babu kudin kupon da aka ci. Don Allah tabbatar da kudin da shagon.';

  @override
  String get voucherRegisterTitle => 'Rika rajistarka a shirin';

  @override
  String get voucherRegisterBody => 'Yi rajista sau daya don karbar kuponai da biyan shaguna kai tsaye daga su.';

  @override
  String get voucherNameLabel => 'Cikakken suna';

  @override
  String get voucherLocationLabel => 'Kauye ko gari';

  @override
  String get voucherRegisterAction => 'Shiga shirin';

  @override
  String get inviteJoinTitle => 'Shiga SatsFarm';

  @override
  String get inviteJoinBody => 'Shigar da lambar gayyata ta amfani guda ɗaya daga jami\'in shirin, ko duba lambar QR.';

  @override
  String get inviteCodeLabel => 'Lambar gayyata';

  @override
  String get inviteScanAction => 'Duba lambar QR';

  @override
  String get inviteSubmitAction => 'Shiga shirin noma';

  @override
  String get inviteInvalidCode => 'Wannan lambar ba ta aiki. Duba ta kuma sake gwadawa.';

  @override
  String get inviteExpiredCode => 'Wannan lambar ta ƙare. Nemi sabuwar lamba daga jami\'in shirin.';

  @override
  String get inviteUsedCode => 'An riga an yi amfani da wannan lambar a wata na\'ura. Nemi sabuwar lamba daga jami\'in shirin.';

  @override
  String get inviteUnavailable => 'Ba a iya haɗawa da SatsFarm ba. Duba haɗin yanar gizo kuma sake gwadawa.';

  @override
  String get inviteStorageError => 'SatsFarm bai iya adana amintaccen shiga a wannan na\'ura ba. Sake gwadawa.';

  @override
  String get farmerBalanceLabel => 'KUDIN TALLAFIN DA SUKA SAMU';

  @override
  String get farmerHistoryLabel => 'Tarihin tallafi';

  @override
  String get farmerHistoryEmpty => 'Tarihin tallafinka zai bayyana a nan.';

  @override
  String get farmerRepaymentLabel => 'Biyan bashi';

  @override
  String get repaymentTypeGrain => 'Hatsi';

  @override
  String get repaymentTypeCash => 'Kuɗi';

  @override
  String get repaymentTypeTransfer => 'Canja wurin kuɗi';

  @override
  String get farmerNoteLabel => 'Bayani';

  @override
  String get switchFarmer => 'Canja manomi';

  @override
  String get switchFarmerTitle => 'A canja asusun manomi?';

  @override
  String get switchFarmerConfirm => 'Wannan zai fita daga asusun manomin a wannan na\'ura. Ba zai canza walat ko kalmomin dawo da walat ba.';

  @override
  String get farmerWalletAction => 'Walat dina';

  @override
  String get farmerRefreshAction => 'Sabunta ma\'auni';

  @override
  String farmerWelcome(String name) {
    return 'Barka da zuwa, $name';
  }

  @override
  String get farmerSupportLabel => 'Tallafin shiri';

  @override
  String get inviteCameraTitle => 'Duba gayyatarka';

  @override
  String get inviteCameraHint => 'Sanya lambar QR ta dashboard a cikin firam.';

  @override
  String get inviteTestNetworkBody => 'SatsFarm na amfani da Mutinynet, cibiyar gwajin Bitcoin. Kuɗin gwaji ba su da darajar kuɗi.';

  @override
  String get checkingFarmerSession => 'Ana duba shigarka ta SatsFarm…';
}
