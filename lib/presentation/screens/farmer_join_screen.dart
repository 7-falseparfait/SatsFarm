import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/voucher_provider.dart';
import '../../widgets/language_toggle_button.dart';

class FarmerJoinScreen extends StatefulWidget {
  const FarmerJoinScreen({super.key});

  @override
  State<FarmerJoinScreen> createState() => _FarmerJoinScreenState();
}

class _FarmerJoinScreenState extends State<FarmerJoinScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const InviteScannerScreen()),
    );
    if (code == null || !mounted) return;
    _codeController.text = code;
    await _redeem(code);
  }

  Future<void> _redeem([String? scannedCode]) async {
    final code = _inviteCode(scannedCode ?? _codeController.text);
    if (code.isEmpty) return;
    final joined = await context.read<VoucherProvider>().redeemInvite(code);
    if (joined && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _inviteCode(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    return uri?.queryParameters['code'] ?? trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final provider = context.watch<VoucherProvider>();
    final errorMessage = switch (provider.joinError) {
      'invalid' => strings.inviteInvalidCode,
      'expired' => strings.inviteExpiredCode,
      'used' => strings.inviteUsedCode,
      'storage' => strings.inviteStorageError,
      'unavailable' => strings.inviteUnavailable,
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppTheme.sand,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              children: [
                Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 11),
                    Text(
                      strings.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const LanguageToggleButton(),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  strings.inviteJoinTitle,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  strings.inviteJoinBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    labelText: strings.inviteCodeLabel,
                    prefixIcon: const Icon(LucideIcons.keyRound),
                  ),
                  onSubmitted: (_) => _redeem(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _MessageCard(message: errorMessage),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: provider.busy ? null : () => _redeem(),
                  icon: provider.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.logIn),
                  label: Text(strings.inviteSubmitAction),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: provider.busy ? null : _scan,
                  icon: const Icon(LucideIcons.scanLine),
                  label: Text(strings.inviteScanAction),
                ),
                const SizedBox(height: 24),
                _NetworkNotice(
                  title: strings.networkNoticeTitle,
                  body: strings.inviteTestNetworkBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InviteScannerScreen extends StatelessWidget {
  const InviteScannerScreen({super.key});

  String? _extractCode(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return null;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return null;
    final uri = Uri.tryParse(rawValue);
    return uri?.queryParameters['code'] ?? rawValue;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(strings.inviteCameraTitle)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final code = _extractCode(capture);
                if (code != null && context.mounted) {
                  Navigator.of(context).pop(code);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              strings.inviteCameraHint,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class FarmerHomeScreen extends StatelessWidget {
  const FarmerHomeScreen({required this.onOpenWallet, super.key});

  final VoidCallback onOpenWallet;

  String _naira(int amount) => '₦${NumberFormat('#,##0').format(amount)}';

  String _repaymentTypeLabel(String? type, AppLocalizations strings) =>
      switch (type) {
        'Grain' => strings.repaymentTypeGrain,
        'Cash' => strings.repaymentTypeCash,
        'Transfer' => strings.repaymentTypeTransfer,
        _ => strings.farmerRepaymentLabel,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final provider = context.watch<VoucherProvider>();
    final account = provider.farmerAccount;
    if (account == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: provider.refreshFarmerAccount,
            child: Text(strings.retry),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.sand,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 10),
                    Text(
                      strings.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const LanguageToggleButton(),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.userRound,
                      color: AppTheme.forest,
                      size: 23,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.farmerWelcome(account.name),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final shouldSwitch = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(strings.switchFarmerTitle),
                          content: Text(strings.switchFarmerConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(strings.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(strings.switchFarmer),
                            ),
                          ],
                        ),
                      );
                      if (shouldSwitch == true && context.mounted) {
                        await context.read<VoucherProvider>().logoutFarmer();
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(strings.switchFarmer),
                  ),
                ),
                if (provider.joinError == 'unavailable') ...[
                  const SizedBox(height: 12),
                  _MessageCard(message: strings.inviteUnavailable),
                ],
                const SizedBox(height: 19),
                Card(
                  color: AppTheme.forest,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.wallet,
                              color: AppTheme.lime,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.farmerBalanceLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: provider.busy
                                  ? null
                                  : provider.refreshFarmerAccount,
                              tooltip: strings.farmerRefreshAction,
                              color: Colors.white,
                              icon: const Icon(LucideIcons.refreshCw),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _naira(account.balanceNgn),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.shieldCheck,
                              color: AppTheme.lime,
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              strings.networkNoticeTitle,
                              style: const TextStyle(
                                color: AppTheme.lime,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: onOpenWallet,
                  icon: const Icon(LucideIcons.walletCards),
                  label: Text(strings.farmerWalletAction),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.ticket,
                      color: AppTheme.forest,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      strings.myVouchers,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (provider.vouchers.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(strings.voucherEmpty),
                    ),
                  )
                else
                  ...provider.vouchers.map((voucher) {
                    final isGrant = voucher.kind.name == 'grant';
                    final status = switch (voucher.status.name) {
                      'spent' => strings.voucherStatusSpent,
                      'closed' => strings.voucherStatusClosed,
                      _ => strings.voucherStatusActive,
                    };
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAF0E4),
                          child: Icon(
                            LucideIcons.ticket,
                            color: AppTheme.forest,
                          ),
                        ),
                        title: Text(
                          voucher.purpose,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${voucher.id} · ${isGrant ? strings.voucherKindGrant : strings.voucherKindLoan} · $status\n${strings.voucherIssuedAmount(_naira(voucher.amount))}${isGrant ? '' : '\n${strings.voucherAmountOwed(_naira(voucher.amountOwedNgn))}'}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _naira(voucher.remainingNgn),
                              style: const TextStyle(
                                color: AppTheme.forest,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _naira(voucher.remainingNgn),
                              style: const TextStyle(
                                color: AppTheme.mutedInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.history,
                      color: AppTheme.forest,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      strings.farmerHistoryLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (account.history.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(strings.farmerHistoryEmpty),
                    ),
                  )
                else
                  ...account.history.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAF0E4),
                          child: Icon(
                            entry.kind == 'Payment'
                                ? LucideIcons.arrowUpRight
                                : LucideIcons.handCoins,
                            color: AppTheme.forest,
                          ),
                        ),
                        title: Text(
                          entry.kind == 'Repayment'
                              ? strings.farmerRepaymentLabel
                              : entry.description,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          entry.kind == 'Repayment'
                              ? '${_repaymentTypeLabel(entry.repaymentType, strings)} · ${entry.time}${entry.note == null ? '' : '\n${strings.farmerNoteLabel}: ${entry.note}'}'
                              : '${entry.kind} · ${entry.time}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _naira(entry.amountNgn),
                          style: const TextStyle(
                            color: AppTheme.forest,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppTheme.forest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(LucideIcons.sprout, size: 21, color: AppTheme.lime),
  );
}

class _NetworkNotice extends StatelessWidget {
  const _NetworkNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shieldCheck, color: AppTheme.olive, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF3ED),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, color: Color(0xFF9B482E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF743D2B)),
            ),
          ),
        ],
      ),
    ),
  );
}
