import 'package:intl/intl.dart';

/// Display/conversion helpers. NGN conversion is a UI mock rate only.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static int satsToNgn(int sats, {int ngnPerSat = 5}) => sats * ngnPerSat;

  static int ngnToSats(int naira, {int ngnPerSat = 5}) {
    if (ngnPerSat <= 0) throw ArgumentError.value(ngnPerSat, 'ngnPerSat');
    return naira ~/ ngnPerSat;
  }

  static String sats(int value) => '${NumberFormat('#,##0').format(value)} sats';
  static String ngn(int value) => '₦${NumberFormat('#,##0').format(value)}';
}
