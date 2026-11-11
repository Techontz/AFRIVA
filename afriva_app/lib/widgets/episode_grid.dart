import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../models/episode.dart';
import 'calm.dart';

/// Episode number grid with range chips (1-30, 31-60, …) showing free,
/// locked and VIP-unlocked episodes.
class EpisodeGrid extends StatefulWidget {
  const EpisodeGrid({
    super.key,
    required this.episodes,
    required this.onTap,
    this.currentNumber,
    this.isVip = false,
    this.rangeSize = 30,
    this.columns = 5,
    this.shrinkWrap = true,
  });

  final List<Episode> episodes;
  final ValueChanged<Episode> onTap;
  final int? currentNumber;
  final bool isVip;
  final int rangeSize;
  final int columns;
  final bool shrinkWrap;

  @override
  State<EpisodeGrid> createState() => _EpisodeGridState();
}

class _EpisodeGridState extends State<EpisodeGrid> {
  late int _range = _initialRange();

  int _initialRange() {
    final cur = widget.currentNumber;
    if (cur == null || widget.episodes.isEmpty) return 0;
    final idx = widget.episodes.indexWhere((e) => e.number == cur);
    return idx < 0 ? 0 : idx ~/ widget.rangeSize;
  }

  @override
  Widget build(BuildContext context) {
    final eps = widget.episodes;
    final ranges = (eps.length / widget.rangeSize).ceil();
    final start = _range * widget.rangeSize;
    final slice = eps.sublist(start.clamp(0, eps.length), (start + widget.rangeSize).clamp(0, eps.length));

    final grid = GridView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 56,
      ),
      itemCount: slice.length,
      itemBuilder: (_, i) {
        final e = slice[i];
        return _EpisodeTile(
          episode: e,
          current: e.number == widget.currentNumber,
          showLock: e.isLocked && !widget.isVip,
          onTap: () {
            Haptics.tap();
            widget.onTap(e);
          },
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (ranges > 1)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ranges,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, r) {
                final from = eps[r * widget.rangeSize].number;
                final to = eps[((r + 1) * widget.rangeSize - 1).clamp(0, eps.length - 1)].number;
                return CalmChip(
                  label: '$from-$to',
                  selected: r == _range,
                  onTap: () => setState(() => _range = r),
                );
              },
            ),
          ),
        if (ranges > 1) const SizedBox(height: 14),
        if (widget.shrinkWrap) grid else Expanded(child: grid),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.current,
    required this.showLock,
    required this.onTap,
  });

  final Episode episode;
  final bool current;
  final bool showLock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final free = episode.isFree;
    return Material(
      color: current
          ? AppColors.primary
          : AppColors.text.withValues(alpha: showLock ? 0.05 : 0.1),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
                child: current
                    ? const _PlayingBars()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${episode.number}',
                            style: TextStyle(
                              color: showLock ? AppColors.textMuted : AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (free) ...[
                            const SizedBox(height: 2),
                            Text(
                              l.episodeFree,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                height: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (!free)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Semantics(
                    label: showLock ? l.episodeLocked : l.episodeVipUnlocked,
                    child: Icon(
                      showLock ? Icons.lock_outline_rounded : Icons.workspace_premium_outlined,
                      size: 11,
                      color: current
                          ? Colors.white
                          : showLock
                              ? AppColors.textDim
                              : AppColors.primary,
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

/// Tiny animated equalizer marking the episode currently playing.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final phase in const [0.0, 0.5, 0.25])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: 6 + 10 * ((_c.value + phase) % 1.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      );
}
