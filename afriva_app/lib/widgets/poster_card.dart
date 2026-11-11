import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../models/drama.dart';
import 'badges.dart';
import 'net_image.dart';

/// Builds a hero tag that is unique per on-screen placement.
String posterHeroTag(Drama d, String scope) => 'poster-$scope-${d.id}';

/// Arguments passed to the drama detail route so it can render instantly
/// (and run the poster hero) before the full payload arrives.
class DramaRouteArgs {
  const DramaRouteArgs({this.drama, this.heroTag});
  final Drama? drama;
  final String? heroTag;
}

/// Opens drama detail with a matching hero animation.
void openDrama(BuildContext context, Drama d, {String? heroTag}) {
  Haptics.tap();
  context.push('/drama/${d.slug}', extra: DramaRouteArgs(drama: d, heroTag: heroTag));
}

/// Full 9:16 artwork: never cropped and nothing drawn over it, so the title
/// printed on the poster stays whole.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.drama, this.heroTag, this.radius, this.cacheWidth = 420});

  final Drama drama;
  final String? heroTag;
  final double? radius;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadii.poster;
    final Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: NetImage(drama.posterUrl, memCacheWidth: cacheWidth),
      ),
    );
    return heroTag == null ? img : Hero(tag: heroTag!, child: img);
  }
}

/// Genre names for captions, falling back to the free-text tags.
List<String> dramaGenres(Drama d, [int n = 2]) {
  final names = d.categories.isNotEmpty ? d.categories.map((c) => c.name) : d.tags;
  return names.take(n).toList();
}

/// Poster card: 9:16 artwork, 2-line title, quiet "Hot · 72 Episodes" caption.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.drama,
    required this.heroScope,
    this.width,
  });

  final Drama drama;
  final String heroScope;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tag = posterHeroTag(drama, heroScope);
    final badge = drama.badge;
    final caption = TextStyle(fontSize: 12, height: 1.3, color: AppColors.textDim, fontWeight: FontWeight.w500);
    return _PressScale(
      onTap: () => openDrama(context, drama, heroTag: tag),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Poster(drama: drama, heroTag: tag),
            const SizedBox(height: 10),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(children: [
                if (badge != null)
                  TextSpan(
                    text: '${badgeLabel(context, badge)} · ',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                TextSpan(text: episodesLabel(context, drama.totalEpisodes)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Height of a card's text block under the poster at the given text scale.
double posterCaptionHeight(TextScaler t) =>
    10 + t.scale(13) * 1.3 * 2 + 3 + t.scale(12) * 1.3 + 2;

/// Width of a card on a shelf: a peek of the next poster on phones.
double shelfItemWidth(double screenWidth) => switch (screenWidth) {
      < 600 => (screenWidth - 32 - 2 * 12) / 2.6,
      < 1024 => (screenWidth - 32 - 3 * 12) / 4.3,
      _ => 170,
    };

/// Lazy horizontal shelf of poster cards.
class PosterShelf extends StatelessWidget {
  const PosterShelf({super.key, required this.dramas, required this.heroScope});
  final List<Drama> dramas;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final w = shelfItemWidth(MediaQuery.sizeOf(context).width);
    final h = w * 16 / 9 + posterCaptionHeight(MediaQuery.textScalerOf(context));
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dramas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => PosterCard(drama: dramas[i], heroScope: heroScope, width: w),
      ),
    );
  }
}

/// "60 Episodes" / "1 Episode" / "Coming soon".
String episodesLabel(BuildContext context, int n) =>
    n <= 0 ? context.l10n.comingSoon : context.l10n.episodesCount(n);

/// Ranking row: outlined numeral, 9:16 thumb, title, genres, views · EP n.
class RankingTile extends StatelessWidget {
  const RankingTile({super.key, required this.rank, required this.drama, required this.heroScope});

  final int rank;
  final Drama drama;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final tag = posterHeroTag(drama, heroScope);
    final text = Theme.of(context).textTheme;
    final genres = dramaGenres(drama);
    final stats = [
      context.l10n.viewsCount(Fmt.compact(drama.views)),
      if (drama.totalEpisodes > 0) context.l10n.posterEpisodeCount(drama.totalEpisodes),
    ].join(' · ');
    return _PressScale(
      onTap: () => openDrama(context, drama, heroTag: tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 44, child: RankNumeral(rank, fontSize: 38)),
            const SizedBox(width: 8),
            SizedBox(width: 56, child: Poster(drama: drama, heroTag: tag, radius: 8, cacheWidth: 180)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600)),
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(genres.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 5),
                  Text(stats, style: TextStyle(fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big outlined rank numeral; top 3 filled with the brand gradient.
class RankNumeral extends StatelessWidget {
  const RankNumeral(this.rank, {super.key, this.fontSize = 44});
  final int rank;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall!.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          height: 1,
          letterSpacing: -2,
        );
    if (rank <= 3) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => AppColors.brandGradient.createShader(r),
        child: Text('$rank', textAlign: TextAlign.center, style: style.copyWith(color: Colors.white)),
      );
    }
    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.textDim,
      ),
    );
  }
}

/// Subtle press-down scale for tappable cards.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: widget.child,
        ),
      );
}
