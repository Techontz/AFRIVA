import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/episode.dart';
import 'badges.dart';

/// Episode number grid with range tabs (1-30, 31-60, …) and lock markers.
class EpisodeGrid extends StatefulWidget {
  const EpisodeGrid({
    super.key,
    required this.episodes,
    required this.onTap,
    this.currentNumber,
    this.isVip = false,
    this.rangeSize = 30,
    this.columns = 6,
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
        childAspectRatio: 0.88,
      ),
      itemCount: slice.length,
      itemBuilder: (_, i) {
        final e = slice[i];
        return _EpisodeTile(
          episode: e,
          current: e.number == widget.currentNumber,
          // The API computes `access` per viewer (VIP, unlocks, series rules); older payloads fall back to isVip.
          showLock: e.access.isNotEmpty ? e.isLocked : e.isLocked && !widget.isVip,
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
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (_, r) {
                final from = eps[r * widget.rangeSize].number;
                final to = eps[((r + 1) * widget.rangeSize - 1).clamp(0, eps.length - 1)].number;
                final sel = r == _range;
                return GestureDetector(
                  onTap: () {
                    Haptics.tap();
                    setState(() => _range = r);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.fast,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: sel ? AppColors.primary : AppColors.textMuted,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                            ),
                        child: Text('$from-$to'),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: AppMotion.normal,
                        width: sel ? 18 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (ranges > 1) const SizedBox(height: 10),
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
    return Material(
      color: current ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
                child: current
                    ? const _PlayingBars()
                    : Text(
                        '${episode.number}',
                        style: TextStyle(
                          color: showLock ? AppColors.textDim : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
              // Scope §02: the viewer sees up front which episodes are free and what locked ones cost.
              Positioned(
                left: 0,
                right: 0,
                bottom: 3,
                child: Center(child: _AccessLabel(episode: episode, locked: showLock, current: current)),
              ),
              if (showLock)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
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

/// "Bure" for free episodes, "VIP" for VIP-only ones, coin price for other locked ones.
class _AccessLabel extends StatelessWidget {
  const _AccessLabel({required this.episode, required this.locked, required this.current});
  final Episode episode;
  final bool locked;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current ? Colors.white : (locked ? AppColors.primary : AppColors.textMuted);
    final style = TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w800, height: 1);
    if (episode.isFree) return Text(context.tr('FREE'), style: style);
    if (!locked) return const SizedBox.shrink();
    if (episode.vipOnly) return Text('VIP', style: style);
    if (episode.priceCoins <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 8),
        const SizedBox(width: 2),
        Text('${episode.priceCoins}', style: style),
      ],
    );
  }
}
