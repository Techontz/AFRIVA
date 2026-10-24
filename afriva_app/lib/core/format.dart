import 'package:intl/intl.dart';

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

  static String date(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());

  static String dateTime(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy, HH:mm').format(d.toLocal());

  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }
}
