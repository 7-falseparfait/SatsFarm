import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/farm_photo_placeholder.dart';
import '../../widgets/language_toggle_button.dart';
import 'receive_screen.dart';
import 'season_goals_screen.dart';
import 'vouchers_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.sand,
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, wallet, _) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
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
                          size: 21,
                          color: AppTheme.lime,
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
                  const SizedBox(height: 24),
                  Text(
                    strings.greeting,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    strings.seasonLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.mutedInk,
                      letterSpacing: 1.1,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 18),
                  HomeVouchersSection(
                    onViewAll: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const VouchersScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FarmPhotoPlaceholder(
                    imageUrl: FarmPhotoPlaceholder.northernFieldsImage,
                    height: 166,
                    icon: LucideIcons.landPlot,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
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
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.mapPin,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.locationNorthernNigeria,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            strings.walletIntro,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BalanceCard(
                    balanceSats: wallet.satsBalance,
                    balanceNgn: wallet.ngnBalance,
                    onReceive: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ReceiveScreen(),
                      ),
                    ),
                    receiveLabel: strings.receive,
                    sendLabel: strings.send,
                    demoLabel: strings.mutinynetDemo,
                    balanceLabel: strings.availableBalance,
                    ngnLabel: strings.ngnEstimateLabel,
                  ),
                  const SizedBox(height: 14),
                  _NetworkNotice(
                    title: strings.networkNoticeTitle,
                    body: wallet.isLinuxDesktop
                        ? strings.networkNoticeBody
                        : strings.onboardingNote,
                  ),
                  if (wallet.error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(message: wallet.error!),
                  ],
                  const SizedBox(height: 24),
                  _SectionHeading(
                    title: strings.fieldAndSeason,
                    trailing: strings.phaseTwo,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FarmPhotoPlaceholder(
                          imageUrl: FarmPhotoPlaceholder.northernFieldsImage,
                          height: 150,
                          borderRadius: 0,
                          icon: LucideIcons.sprout,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              margin: const EdgeInsets.all(14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.lime,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                strings.phaseTwo,
                                style: const TextStyle(
                                  color: AppTheme.forest,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.seasonCardTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.seasonCardBody,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SeasonGoalsScreen(),
                                  ),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: Text(strings.startPlanning),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeading(title: strings.activityTitle),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _IconBadge(
                            icon: LucideIcons.activity,
                            background: Color(0xFFEAF0E7),
                            foreground: AppTheme.forest,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              strings.activityEmpty,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wallet.isLinuxDesktop) ...[
                    const SizedBox(height: 14),
                    Text(
                      strings.linuxWalletLimitation,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedInk),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balanceSats,
    required this.balanceNgn,
    required this.onReceive,
    required this.receiveLabel,
    required this.sendLabel,
    required this.demoLabel,
    required this.balanceLabel,
    required this.ngnLabel,
  });

  final int balanceSats;
  final int balanceNgn;
  final VoidCallback onReceive;
  final String receiveLabel;
  final String sendLabel;
  final String demoLabel;
  final String balanceLabel;
  final String ngnLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.forest,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24153C2B),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.wallet, color: AppTheme.lime, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                balanceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                demoLabel,
                style: const TextStyle(
                  color: AppTheme.lime,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          CurrencyFormatter.sats(balanceSats),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          CurrencyFormatter.ngn(balanceNgn),
          style: const TextStyle(
            color: Color(0xFFD5DED4),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          ngnLabel,
          style: const TextStyle(color: Color(0xFFB8C7B9), fontSize: 11),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onReceive,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: AppTheme.forest,
                ),
                icon: const Icon(LucideIcons.arrowDownLeft, size: 18),
                label: Text(receiveLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFFB8C7B9),
                  side: const BorderSide(color: Color(0x668FA393)),
                ),
                icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                label: Text(sendLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NetworkNotice extends StatelessWidget {
  const _NetworkNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D9),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0D49A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.info, size: 19, color: Color(0xFF77500F)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF553900),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF634A20),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(
            color: AppTheme.olive,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
    ],
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: foreground, size: 19),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9E6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.circleAlert, color: Color(0xFF9B2C22), size: 18),
        const SizedBox(width: 9),
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
