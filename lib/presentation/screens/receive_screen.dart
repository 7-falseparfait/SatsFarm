import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(title: Text(strings.receive)),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, wallet, _) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    strings.receive,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.walletIntro,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _ReceiveMethodCard(
                    icon: LucideIcons.qrCode,
                    title: strings.receiveOnchainTitle,
                    description: strings.receiveOnchainBody,
                    iconColor: AppTheme.forest,
                    iconBackground: const Color(0xFFEAF0E7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: wallet.isBusy
                              ? null
                              : () async {
                                  try {
                                    await wallet.generateReceiveAddress();
                                  } catch (_) {
                                    // Provider exposes the actionable error below.
                                  }
                                },
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: Text(strings.generateAddress),
                        ),
                        if (wallet.currentReceiveAddress != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppTheme.sand,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SelectableText(
                                  wallet.currentReceiveAddress!,
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _copyToClipboard(
                                      context,
                                      wallet.currentReceiveAddress!,
                                      strings,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.copy,
                                      size: 16,
                                    ),
                                    label: Text(strings.copyAddress),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReceiveMethodCard(
                    icon: LucideIcons.zap,
                    title: strings.receiveLightningTitle,
                    description: strings.receiveLightningBody,
                    iconColor: const Color(0xFF815500),
                    iconBackground: const Color(0xFFFFF2D9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: wallet.isLinuxDesktop
                              ? null
                              : () async {
                                  try {
                                    await wallet.generateInvoice(
                                      amountSats: 1000,
                                    );
                                  } catch (_) {
                                    // Provider exposes the actionable error below.
                                  }
                                },
                          icon: const Icon(LucideIcons.zap, size: 18),
                          label: Text(strings.generateInvoice),
                        ),
                        if (wallet.isLinuxDesktop) ...[
                          const SizedBox(height: 9),
                          Text(
                            strings.nodeUnavailable,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (wallet.currentInvoice != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppTheme.sand,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: SelectableText(
                              wallet.currentInvoice!,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (wallet.error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: wallet.error!),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.forest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          color: AppTheme.lime,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            wallet.isLinuxDesktop
                                ? strings.networkNoticeBody
                                : strings.onboardingNote,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(
    BuildContext context,
    String value,
    AppLocalizations strings,
  ) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.addressCopied)));
  }
}

class _ReceiveMethodCard extends StatelessWidget {
  const _ReceiveMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.iconBackground,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color iconBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

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
