import 'package:share_plus/share_plus.dart';

import '../models/drama.dart';
import 'i18n.dart';

/// Shares a drama using the platform share sheet.
Future<void> shareDrama(Drama d, {int? episode}) async {
  final headline = episode != null
      ? trNow('Watch "{title}" - Episode {n} on Afriva', {'n': episode, 'title': d.title})
      : trNow('Watch "{title}" on Afriva', {'title': d.title});
  final text = '$headline\n'
      '${d.synopsis.isNotEmpty ? '${d.synopsis.split('\n').first}\n' : ''}'
      'https://afriva.com/drama/${d.slug}${episode != null ? '/ep/$episode' : ''}';
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: d.title));
  } catch (_) {
    // Sharing unavailable on this platform.
  }
}
