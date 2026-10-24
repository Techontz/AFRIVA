import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../state/auth_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/episode_grid.dart';
import '../../widgets/net_image.dart';
import '../../widgets/sheet.dart';

/// Bottom sheet listing all episodes with ranges; resolves to the tapped episode.
Future<Episode?> showEpisodesSheet(
  BuildContext context, {
  required Drama drama,
  required List<Episode> episodes,
  int? currentNumber,
}) {
  return showAfrivaSheet<Episode>(
    context,
    heightFactor: 0.72,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      final isVip = ctx.select<AuthState, bool>((a) => a.isVip);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 48, height: 64, child: NetImage(drama.posterUrl, memCacheWidth: 150)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drama.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${episodes.length} episodes'
                        '${drama.freeEpisodes > 0 && !isVip ? ' · EP 1-${drama.freeEpisodes} free' : ''}',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (isVip) const VipPill(),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: EpisodeGrid(
                episodes: episodes,
                currentNumber: currentNumber,
                isVip: isVip,
                shrinkWrap: false,
                onTap: (e) => Navigator.of(ctx).pop(e),
              ),
            ),
          ],
        ),
      );
    },
  );
}
