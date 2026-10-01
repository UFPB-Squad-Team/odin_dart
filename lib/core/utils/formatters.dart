import 'package:intl/intl.dart';

final Map<int, NumberFormat> _formats = <int, NumberFormat>{};

NumberFormat _formatFor(int decimals) {
  return _formats.putIfAbsent(
    decimals,
    () => NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: decimals,
    ),
  );
}

String formatNumber(double value, {int decimals = 0}) {
  return _formatFor(decimals).format(value);
}

String formatWithUnit(double value, {int decimals = 0, String? unit}) {
  final text = formatNumber(value, decimals: decimals);
  if (unit == null || unit.isEmpty) return text;
  return unit == '%' ? '$text%' : '$text $unit';
}
