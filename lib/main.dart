import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'l10n/app_localizations.dart';
import 'providers/voucher_provider.dart';
import 'providers/wallet_provider.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/farmer_join_screen.dart';
import 'presentation/screens/recovery_phrase_screen.dart';

void main() {
  runApp(const SatsFarmApp());
}

class SatsFarmApp extends StatelessWidget {
  const SatsFarmApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => VoucherProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
    ],
    child: Consumer<LanguageProvider>(
      builder: (context, language, _) => MaterialApp(
        title: 'SatsFarm',
        theme: AppTheme.light,
        locale: language.locale,
        supportedLocales: const [Locale('en'), Locale('ha')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          _HausaMaterialLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          _HausaCupertinoLocalizationsDelegate(),
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const FarmerStartupGate(),
      ),
    ),
  );
}

class FarmerStartupGate extends StatefulWidget {
  const FarmerStartupGate({super.key});

  @override
  State<FarmerStartupGate> createState() => _FarmerStartupGateState();
}

class _FarmerStartupGateState extends State<FarmerStartupGate> {
  bool _loading = true;
  bool _storageUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _storageUnavailable = false;
    });
    try {
      await context.read<VoucherProvider>().initializeInviteSession();
    } on PlatformException {
      if (!mounted) return;
      setState(() => _storageUnavailable = true);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _storageUnavailable = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(strings.checkingFarmerSession),
            ],
          ),
        ),
      );
    }
    if (_storageUnavailable) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.secureStorageUnavailable),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadSession,
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Consumer<VoucherProvider>(
      builder: (context, farmer, _) => farmer.hasFarmerSession
          ? FarmerHomeScreen(
              onOpenWallet: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const WalletStartupGate(),
                  ),
                );
                if (context.mounted) {
                  await context.read<VoucherProvider>().refreshFarmerAccount();
                }
              },
            )
          : const FarmerJoinScreen(),
    );
  }
}

/// Restores a keyring-backed wallet before showing Home. A locked/unavailable
/// keyring stays on this gate instead of presenting an empty wallet state.
class WalletStartupGate extends StatefulWidget {
  const WalletStartupGate({super.key});

  @override
  State<WalletStartupGate> createState() => _WalletStartupGateState();
}

class _WalletStartupGateState extends State<WalletStartupGate> {
  bool _loading = true;
  bool _walletFound = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final walletProvider = context.read<WalletProvider>();
      final directory = await getApplicationSupportDirectory();
      final walletFound = await walletProvider.loadSavedWallet(
        storageDirectory: '${directory.path}/satsfarm/node',
      );
      if (!mounted) return;
      setState(() {
        _walletFound = walletFound;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(strings.loadingWallet),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.secureStorageUnavailable),
                const SizedBox(height: 12),
                SelectableText(_error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadWallet,
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_walletFound) return const OnboardingScreen();

    return Consumer<WalletProvider>(
      builder: (context, wallet, _) => wallet.needsBackupConfirmation
          ? const RecoveryPhraseScreen()
          : const HomeScreen(),
    );
  }
}

/// Backward-compatible root name used by the starter widget test.
class MyApp extends SatsFarmApp {
  const MyApp({super.key});
}

/// Flutter does not ship Hausa framework strings. Use English framework
/// labels for Hausa while keeping the app's own locale and ARB strings Hausa.
class _HausaMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _HausaMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ha';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_HausaMaterialLocalizationsDelegate old) => false;
}

class _HausaCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _HausaCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ha';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_HausaCupertinoLocalizationsDelegate old) => false;
}
