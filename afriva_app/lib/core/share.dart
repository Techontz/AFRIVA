import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/drama.dart';

/// Shares a drama using the platform share sheet.
Future<void> shareDrama(Drama d, {int? episode}) async {
  final l = L10n.current;
  final headline = episode != null ? l.shareWatchEpisode(d.title, episode) : l.shareWatch(d.title);
  final text = '$headline\n'
      '${d.synopsis.isNotEmpty ? '${d.synopsis.split('\n').first}\n' : ''}'
      'https://afriva.co.tz/drama/${d.slug}${episode != null ? '/ep/$episode' : ''}';
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: d.title));
  } catch (_) {
    // Sharing unavailable on this platform.
  }
}
