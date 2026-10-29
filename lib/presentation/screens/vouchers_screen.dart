import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/voucher_provider.dart';
import '../../services/ngo_api_service.dart';
import 'farmer_join_screen.dart';

/// Program vouchers are the primary farmer experience: the desk sends input
/// support here and the farmer redeems it at approved dealers. Wallet funds
/// and transfers stay available below.
class VouchersScreen extends StatelessWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(title: Text(strings.myVouchers)),
      body: SafeArea(
        child: Consumer<VoucherProvider>(
          builder: (context, vouchers, _) => Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _VoucherBody(isCompact: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact summary for the home screen: shows the headline voucher balance
/// and the latest vouchers sent by the program desk.
class HomeVouchersSection extends StatefulWidget {
  const HomeVouchersSection({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  State<HomeVouchersSection> createState() => _HomeVouchersSectionState();
}

class _HomeVouchersSectionState extends State<HomeVouchersSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VoucherProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Consumer<VoucherProvider>(
      builder: (context, vouchers, _) {
        if (vouchers.checkedRegistration && vouchers.registered) {
          return _VoucherBody(
            isCompact: true,
            onViewAll: widget.onViewAll,
            emptyLabel: strings.voucherEmpty,
          );
        }
        if (vouchers.checkedRegistration) {
          return const _RegisterCard();
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _VoucherBody extends StatelessWidget {
  const _VoucherBody({
    required this.isCompact,
    this.onViewAll,
    this.emptyLabel,
  });

  final bool isCompact;
  final VoidCallback? onViewAll;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final vouchers = context.watch<VoucherProvider>();
    final shown = isCompact
        ? vouchers.vouchers.take(2).toList()
        : vouchers.vouchers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VoucherHeader(isCompact: isCompact),
        if (vouchers.error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9E6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.circleAlert,
                  color: Color(0xFF9B2C22),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    vouchers.error!,
                    style: const TextStyle(
                      color: Color(0xFF7F2018),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!isCompact) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: vouchers.busy ? null : () => vouchers.refresh(),
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(strings.voucherRefresh),
            ),
          ),
        ],
        if (shown.isEmpty && vouchers.error == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text(
              emptyLabel ?? strings.voucherEmpty,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        for (final voucher in shown) ...[
          const SizedBox(height: 12),
          _VoucherCard(voucher: voucher),
        ],
        if (isCompact && onViewAll != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onViewAll,
              child: Text(strings.myVouchers),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoucherHeader extends StatelessWidget {
  const _VoucherHeader({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final vouchers = context.watch<VoucherProvider>();
    final name = vouchers.profileName ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.forest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.ticket,
                  size: 17,
                  color: AppTheme.lime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? strings.myVouchers : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.shieldCheck,
                size: 16,
                color: AppTheme.lime,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.vouchersGrantTotal,
            style: const TextStyle(
              color: Color(0xFFB8C7B9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.ngn(vouchers.activeGrantNgn),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            strings.vouchersSubcopy,
            style: const TextStyle(color: Color(0xFFD5DED4), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final VoucherRecord voucher;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final isGrant = voucher.kind == VoucherKind.grant;
    final active = voucher.status == VoucherStatus.active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12153C2B),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher.purpose,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isGrant
                      ? const Color(0xFFEAF0E7)
                      : const Color(0xFFFDF3D9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isGrant ? strings.voucherKindGrant : strings.voucherKindLoan,
                  style: TextStyle(
                    color: isGrant ? AppTheme.forest : const Color(0xFF7C5512),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.ngn(voucher.remainingNgn),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            '${CurrencyFormatter.ngn(voucher.amount)} · ${voucher.id}',
            style: const TextStyle(color: AppTheme.mutedInk, fontSize: 11),
          ),
          if (!isGrant) ...[
            const SizedBox(height: 4),
            Text(
              strings.voucherAmountOwed(
                CurrencyFormatter.ngn(voucher.amountOwedNgn),
              ),
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: voucher.spentFraction,
              minHeight: 7,
              backgroundColor: const Color(0xFFEAF0E7),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.olive),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher.createdAt,
                  style: const TextStyle(
                    color: AppTheme.mutedInk,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                switch (voucher.status) {
                  VoucherStatus.active => strings.voucherStatusActive,
                  VoucherStatus.spent => strings.voucherStatusSpent,
                  VoucherStatus.closed => strings.voucherStatusClosed,
                },
                style: TextStyle(
                  color: active ? AppTheme.olive : AppTheme.mutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if (active && voucher.remainingNgn > 0) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                builder: (_) => _RedeemSheet(voucher: voucher),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.forest,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(LucideIcons.store, size: 17),
              label: Text(strings.voucherRedeem),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet that takes a dealer invoice and waits for settlement.
class _RedeemSheet extends StatefulWidget {
  const _RedeemSheet({required this.voucher});

  final VoucherRecord voucher;

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  final TextEditingController _invoice = TextEditingController();
  PaymentRecord? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _invoice.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_invoice.text.trim().length < 60) {
      setState(() => _error = 'Paste the complete BOLT11 invoice.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final payment = await context.read<VoucherProvider>().redeem(
      voucherId: widget.voucher.id,
      invoice: _invoice.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = payment;
      if (payment.state == PaymentState.failed) {
        _error = context.read<VoucherProvider>().error;
      }
    });
  }

  Future<void> _scanInvoice() async {
    final invoice = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const DealerInvoiceScannerScreen(),
      ),
    );
    if (invoice == null || !mounted) return;
    setState(() {
      _invoice.text = invoice;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.voucherRedeem,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 3),
          Text(
            widget.voucher.purpose,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _invoice,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              hintText: strings.voucherRedeemHint,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scanInvoice,
            icon: const Icon(LucideIcons.scanLine, size: 17),
            label: Text(strings.voucherScanInvoice),
          ),
          const SizedBox(height: 6),
          Text(
            strings.voucherRateLabel,
            style: const TextStyle(color: AppTheme.mutedInk, fontSize: 10),
          ),
          const SizedBox(height: 14),
          if (_busy)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(strings.voucherPayingNow),
                  ],
                ),
              ),
            ),
          if (_result != null && !_busy) ...[
            if (_result!.state == PaymentState.settled)
              _ResultTile(
                color: const Color(0xFFEAF0E7),
                icon: LucideIcons.circleCheck,
                iconColor: AppTheme.forest,
                title: strings.redeemSettled,
                body:
                    '${CurrencyFormatter.ngn(_result!.amountNgn)} · ${_result!.amountSats} sats',
              )
            else if (_result!.state == PaymentState.pending)
              _ResultTile(
                color: const Color(0xFFFFF2D9),
                icon: LucideIcons.clock,
                iconColor: const Color(0xFF77500F),
                title: strings.redeemStillPending,
                body: strings.redeemStillPendingBody,
              )
            else
              _ResultTile(
                color: const Color(0xFFFFE9E6),
                icon: LucideIcons.circleAlert,
                iconColor: const Color(0xFF9B2C22),
                title: _error ?? strings.redeemFailed,
                body: strings.redeemFailedBody,
              ),
            const SizedBox(height: 4),
          ],
          if (!_busy)
            FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.forest,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(LucideIcons.badgeCheck, size: 17),
              label: Text(strings.voucherRedeemSubmit),
            ),
        ],
      ),
    );
  }
}

class DealerInvoiceScannerScreen extends StatefulWidget {
  const DealerInvoiceScannerScreen({super.key});

  @override
  State<DealerInvoiceScannerScreen> createState() =>
      _DealerInvoiceScannerScreenState();
}

class _DealerInvoiceScannerScreenState
    extends State<DealerInvoiceScannerScreen> {
  bool _completed = false;

  void _onDetect(BarcodeCapture capture) {
    if (_completed || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null ||
        value.length < 60 ||
        !value.toLowerCase().startsWith('ln')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.voucherQrInvalid)),
      );
      return;
    }
    _completed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(strings.voucherScanTitle)),
      body: Column(
        children: [
          Expanded(child: MobileScanner(onDetect: _onDetect)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              strings.voucherScanHint,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(body, style: const TextStyle(fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final provider = context.watch<VoucherProvider>();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: LucideIcons.userPlus),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.inviteJoinTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.inviteJoinBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: provider.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FarmerJoinScreen(),
                    ),
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.forest,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(strings.inviteSubmitAction),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0E7),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: AppTheme.forest, size: 18),
  );
}
