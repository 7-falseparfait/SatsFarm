import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/farm_photo_placeholder.dart';
import '../../widgets/language_toggle_button.dart';
import 'home_screen.dart';
import 'recovery_phrase_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.sand,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.forest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.sprout,
                        color: AppTheme.lime,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strings.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const LanguageToggleButton(),
                  ],
                ),
                const SizedBox(height: 22),
                FarmPhotoPlaceholder(
                  imageUrl: FarmPhotoPlaceholder.northernFieldsImage,
                  height: 260,
                  icon: LucideIcons.landPlot,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lime,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            strings.locationNorthernNigeria,
                            style: const TextStyle(
                              color: AppTheme.forest,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          strings.onboardingTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          strings.onboardingBody,
                          style: const TextStyle(
                            color: Color(0xFFF0F3EC),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SecurityCard(
                  title: strings.walletSecurityTitle,
                  body: strings.walletSecurityBody,
                ),
                const SizedBox(height: 14),
                Consumer<WalletProvider>(
                  builder: (context, wallet, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: wallet.isBusy
                            ? null
                            : () async {
                                try {
                                  final support =
                                      await getApplicationSupportDirectory();
                                  await wallet.createWallet(
                                    storageDirectory:
                                        '${support.path}/satsfarm/node',
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const RecoveryPhraseScreen(),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  wallet.reportError(error);
                                }
                              },
                        icon: wallet.isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.wallet, size: 19),
                        label: Text(strings.createWallet),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: wallet.isBusy
                            ? null
                            : () => _restoreWallet(context, wallet, strings),
                        icon: const Icon(LucideIcons.keyRound, size: 18),
                        label: Text(strings.restoreWallet),
                      ),
                      if (wallet.error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorMessage(message: wallet.error!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 15,
                      color: AppTheme.olive,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        strings.onboardingNote,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedInk,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreWallet(
    BuildContext context,
    WalletProvider wallet,
    AppLocalizations strings,
  ) async {
    final controller = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.restoreWallet),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: strings.recoveryPhraseTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(strings.continueButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (phrase == null || phrase.isEmpty || !context.mounted) return;
    try {
      final support = await getApplicationSupportDirectory();
      await wallet.restoreWallet(
        phrase,
        storageDirectory: '${support.path}/satsfarm/node',
      );
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
      }
    } catch (error) {
      wallet.reportError(error);
    }
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            LucideIcons.shieldCheck,
            size: 20,
            color: AppTheme.forest,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9E6),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.circleAlert, color: Color(0xFF9B2C22), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            message,
            style: const TextStyle(color: Color(0xFF7F2018), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
