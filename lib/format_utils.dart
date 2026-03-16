import 'package:intl/intl.dart';

class FormatUtils {
  static final _priceFormatter = NumberFormat('#,##0.00');

  /// Formats a number with comma separators and specified decimal places.
  static String formatNumber(num value, {int decimalPlaces = 2}) {
    final pattern = decimalPlaces > 0
        ? '#,##0.${'0' * decimalPlaces}'
        : '#,##0';
    return NumberFormat(pattern).format(value);
  }

  /// Formats a currency value with comma separators and 2 decimal places.
  static String formatCurrency(num value) {
    return _priceFormatter.format(value);
  }

  /// Formats a large number using compact notation (e.g., 1.2M, 3.4B) with comma fallbacks for smaller numbers.
  static String formatLargeNumber(num value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return formatNumber(value, decimalPlaces: 0);
  }
}
