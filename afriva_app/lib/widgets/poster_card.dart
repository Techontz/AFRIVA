import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
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

/// 3:4 poster with badge, bottom fade and "EP n" count.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.drama, this.heroTag, this.showEpisodes = true, this.radius});

  final Drama drama;
  final String? heroTag;
  final bool showEpisodes;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadii.poster;
    Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: NetImage(drama.posterUrl, memCacheWidth: 420),
      ),
    );
    if (heroTag != null) {
      img = Hero(tag: heroTag!, child: img);
    }
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          img,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                gradient: AppColors.posterFade,
              ),
            ),
          ),
          if (drama.badge != null)
            Positioned(top: 0, left: 0, child: DramaBadge(drama.badge!)),
          if (showEpisodes && drama.totalEpisodes > 0)
            Positioned(
              right: 6,
              bottom: 6,
              child: Text(
                'EP ${drama.totalEpisodes}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Poster card: 3:4 poster, 2-line title, "60 Episodes", one light chip.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.drama,
    required this.heroScope,
    this.width,
    this.showChips = true,
  });

  final Drama drama;
  final String heroScope;
  final double? width;
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    final tag = posterHeroTag(drama, heroScope);
    final text = Theme.of(context).textTheme;
    return _PressScale(
      onTap: () => openDrama(context, drama, heroTag: tag),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Poster(drama: drama, heroTag: tag, showEpisodes: false),
            const SizedBox(height: 7),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(fontSize: 13, height: 1.25, color: AppColors.text),
            ),
            const SizedBox(height: 3),
            Text(
              episodesLabel(drama.totalEpisodes),
              style: text.labelSmall!.copyWith(
                color: AppColors.textDim,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showChips && drama.chips.isNotEmpty) ...[
              const SizedBox(height: 5),
              TagChip(drama.chips.first, dense: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// "60 Episodes" / "1 Episode" / "Coming soon".
String episodesLabel(int n) => n <= 0 ? 'Coming soon' : n == 1 ? '1 Episode' : '$n Episodes';

/// Ranking row: big outlined numeral, thumb, title, tags, views.
class RankingTile extends StatelessWidget {
  const RankingTile({super.key, required this.rank, required this.drama, required this.heroScope});

  final int rank;
  final Drama drama;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final tag = posterHeroTag(drama, heroScope);
    final text = Theme.of(context).textTheme;
    return _PressScale(
      onTap: () => openDrama(context, drama, heroTag: tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 44, child: RankNumeral(rank)),
            const SizedBox(width: 6),
            SizedBox(width: 72, child: Poster(drama: drama, heroTag: tag, showEpisodes: false, radius: 8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 6),
                  if (drama.chips.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: [for (final c in drama.chips) TagChip(c, dense: true)],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text('${Fmt.compact(drama.views)} views',
                          style: text.labelSmall!.copyWith(color: AppColors.textMuted)),
                      if (drama.totalEpisodes > 0) ...[
                        const SizedBox(width: 10),
                        Text(episodesLabel(drama.totalEpisodes), style: text.labelSmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big outlined rank numeral; top 3 rendered in the brand gradient.
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
    final top = rank <= 3;
    final outline = Text(
      '$rank',
      textAlign: TextAlign.center,
      style: style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = top ? AppColors.primary : AppColors.textDim,
      ),
    );
    if (!top) return outline;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => AppColors.brandGradient.createShader(r),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('$rank',
              textAlign: TextAlign.center,
              style: style.copyWith(color: Colors.white.withValues(alpha: 0.18))),
          outline,
        ],
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
