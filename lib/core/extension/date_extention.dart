import 'package:intl/intl.dart';

extension FriendlyDate on DateTime {
  String get friendlyDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);

    if (date == today) {
      return 'Today';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(this);
    }
  }

  /// Always format as: Full Month + Day + Year (e.g. "September 15 2025")
  String get monthDayYear {
    return DateFormat('MMMM d yyyy').format(this);
  }

  /// Format as: MMMM yyyy (e.g. "December 2025")
  String get monthYear {
    return DateFormat('MMMM yyyy').format(this);
  }

  /// Format as: YYYY-MM-DD (e.g. "2026-02-01")
  String get isoDate {
    return DateFormat('yyyy-MM-dd').format(this);
  }
}
