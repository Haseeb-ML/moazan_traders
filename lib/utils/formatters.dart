import 'package:intl/intl.dart';

/// Shared currency and date formatting helpers.
class AppFormatters {
  static final NumberFormat _currency = NumberFormat('#,##0.##', 'en_US');
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy');

  static String formatRs(double amount) {
    final prefix = amount < 0 ? '-Rs. ' : 'Rs. ';
    return '$prefix${_currency.format(amount.abs())}';
  }

  static String formatNumber(double amount) => _currency.format(amount);

  static String formatDate(DateTime date) => _date.format(date);

  static String formatShortDate(DateTime date) => _shortDate.format(date);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

enum DateFilterPreset {
  today,
  thisWeek,
  thisMonth,
  allTime,
  custom,
}

extension DateFilterPresetLabel on DateFilterPreset {
  String get label {
    switch (this) {
      case DateFilterPreset.today:
        return 'Today';
      case DateFilterPreset.thisWeek:
        return 'This Week';
      case DateFilterPreset.thisMonth:
        return 'This Month';
      case DateFilterPreset.allTime:
        return 'All Time';
      case DateFilterPreset.custom:
        return 'Custom Range';
    }
  }
}
