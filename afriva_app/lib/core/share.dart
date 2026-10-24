import 'package:share_plus/share_plus.dart';

import '../models/drama.dart';

/// Shares a drama using the platform share sheet.
Future<void> shareDrama(Drama d, {int? episode}) async {
  final ep = episode != null ? ' — Episode $episode' : '';
  final text = 'Watch "${d.title}"$ep on Afriva\n'
      '${d.synopsis.isNotEmpty ? '${d.synopsis.split('\n').first}\n' : ''}'
      'https://afriva.com/drama/${d.slug}${episode != null ? '/ep/$episode' : ''}';
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: d.title));
  } catch (_) {
    // Sharing unavailable on this platform.
  }
}
