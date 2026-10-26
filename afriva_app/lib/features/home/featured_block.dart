import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../widgets/badges.dart';
import '../../widgets/poster_card.dart';

/// Top-of-Home featured block: one large card followed by two compact
/// horizontal cards, built from the first three home banners.
class FeaturedBlock extends StatelessWidget {
  const FeaturedBlock({super.key, required this.dramas});
  final List<Drama> dramas;

  @override
  Widget build(BuildContext context) {
    final items = dramas.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          _FeaturedCard(drama: items.first, large: true),
          for (final d in items.skip(1)) ...[
            const SizedBox(height: 12),
            _FeaturedCard(drama: d, large: false),
          ],
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.drama, required this.large});
  final Drama drama;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tag = posterHeroTag(drama, large ? 'featured-main' : 'featured');
    final chips = drama.chips.take(large ? 3 : 1).toList();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDrama(context, drama, heroTag: tag),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: large ? 132 : 90,
                child: Poster(drama: drama, heroTag: tag, showEpisodes: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  // Match the poster height so chips can sit at the bottom.
                  height: (large ? 132 : 90) * 4 / 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drama.title,
                        maxLines: large ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: large
                            ? text.titleLarge!.copyWith(
                                fontSize: 20, color: AppColors.primary, height: 1.2)
                            : text.titleSmall!.copyWith(fontSize: 15, color: AppColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episodesLabel(context, drama.totalEpisodes),
                        style: text.labelSmall!.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ClipRect(
                          child: Text(
                          drama.synopsis,
                          maxLines: large ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(
                            color: AppColors.chipText,
                            fontSize: large ? 13 : 12,
                            height: 1.4,
                          ),
                        ),
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (final c in chips)
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: TagChip(c, dense: true),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
