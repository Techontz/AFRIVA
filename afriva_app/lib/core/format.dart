import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import 'config.dart';

class Fmt {
  Fmt._();

  static final _compact = NumberFormat.compact(locale: 'en');
  static final _grouped = NumberFormat.decimalPattern('en');

  /// 1250000 → "1.3M"
  static String compact(num n) => _compact.format(n);

  /// 10000 → "10,000"
  static String grouped(num n) => _grouped.format(n);

  /// 10000, "TZS" → "10,000 TZS"
  static String money(num amount, [String? currency]) =>
      '${_grouped.format(amount)} ${currency ?? AppConfig.currency}';

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String date(DateTime? d) => d == null ? '-' : _format('d MMM yyyy', d);

  static String dateTime(DateTime? d) => d == null ? '-' : _format('d MMM yyyy, HH:mm', d);

  static String relative(DateTime? d) {
    if (d == null) return '';
    final l = L10n.current;
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inHours < 1) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
    return date(d);
  }

  static String _format(String pattern, DateTime d) {
    try {
      return DateFormat(pattern, L10n.code).format(d.toLocal());
    } catch (_) {
      // Locale date symbols not loaded (e.g. in plain unit tests).
      return DateFormat(pattern, 'en').format(d.toLocal());
    }
  }
}
