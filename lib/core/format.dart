import 'package:intl/intl.dart';

final _wholeRupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _rupeesAndPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// ₹1,440 or ₹1,440.50, with Indian digit grouping (₹1,00,000).
String formatRupees(double amount) =>
    amount == amount.roundToDouble() ? _wholeRupees.format(amount) : _rupeesAndPaise.format(amount);

/// "750ml × 12/case", or "12/case" when the volume is unknown.
String packSize(int? unitVolumeMl, int unitsPerCase) {
  if (unitVolumeMl == null) return '$unitsPerCase/case';
  final volume = unitVolumeMl >= 1000 && unitVolumeMl % 1000 == 0 ? '${unitVolumeMl ~/ 1000}L' : '${unitVolumeMl}ml';
  return '$volume × $unitsPerCase/case';
}
