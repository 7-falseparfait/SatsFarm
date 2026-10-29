import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/language_toggle_button.dart';
import 'home_screen.dart';

/// Displays the recovery phrase and requires explicit backup confirmation.
class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({super.key});

  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  bool _confirmed = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletProvider>();
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: Text(strings.recoveryPhraseTitle),
        actions: const [LanguageToggleButton()],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2D9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0D49A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.shieldAlert,
                        color: Color(0xFF77500F),
                        size: 20,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          strings.recoveryPhraseWarning,
                          style: const TextStyle(
                            color: Color(0xFF553900),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.keyRound,
                              size: 18,
                              color: AppTheme.forest,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.recoveryPhraseTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppTheme.sand,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: SelectableText(
                            wallet.recoveryPhrase ?? '',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: CheckboxListTile(
                    value: _confirmed,
                    onChanged: (value) =>
                        setState(() => _confirmed = value ?? false),
                    title: Text(
                      strings.iSavedPhrase,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                if (wallet.error != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    wallet.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: !_confirmed || _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await wallet.confirmRecoveryPhrase();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            }
                          } catch (error) {
                            wallet.reportError(error);
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: Text(strings.continueToWallet),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
