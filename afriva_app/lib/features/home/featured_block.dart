import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../widgets/net_image.dart';
import '../../widgets/poster_card.dart';

/// Time each slide stays up before auto-advancing (matches the website).
const heroInterval = Duration(seconds: 5);

/// Brand easing used by the website hero (`ease-brand`).
const _ease = Cubic(0.22, 1, 0.36, 1);

/// Top-of-Home featured slider, mirroring the website's "Cinematic" hero on
/// mobile: blurred poster backdrop, sharp 9:16 poster, meta line, title,
/// Play / More info and progress dots. Auto-advances every [heroInterval]
/// (paused while touched, scrolled away, off screen or with reduced motion)
/// and can be swiped left / right.
class FeaturedBlock extends StatefulWidget {
  const FeaturedBlock({super.key, required this.dramas, this.topInset = 0});
  final List<Drama> dramas;

  /// Height of the see-through header floating over the slider.
  final double topInset;

  @override
  State<FeaturedBlock> createState() => _FeaturedBlockState();
}

class _FeaturedBlockState extends State<FeaturedBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: heroInterval)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _go(_index + 1);
    });

  int _index = 0;
  int _prev = 0;
  // False until the first slide change, so the first slide shows without animating in.
  bool _changed = false;
  bool _touching = false;
  bool _visible = true;
  bool _tickerOn = true;
  bool _reduced = false;
  bool _visibilityQueued = false;
  double _dragDx = 0;
  ScrollPosition? _position;

  int get _count => widget.dramas.length;
  bool get _autoplay => _count > 1 && !_reduced;
  bool get _paused => !_autoplay || _touching || !_visible || !_tickerOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerOn = TickerMode.valuesOf(context).enabled;
    _reduced = MediaQuery.disableAnimationsOf(context);
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _position) {
      _position?.removeListener(_queueVisibility);
      _position = pos?..addListener(_queueVisibility);
    }
    _sync();
    _precacheNext();
  }

  @override
  void didUpdateWidget(FeaturedBlock old) {
    super.didUpdateWidget(old);
    if (_index >= _count) {
      _index = 0;
      _prev = 0;
      _progress.value = 0;
    }
    _sync();
  }

  @override
  void dispose() {
    _position?.removeListener(_queueVisibility);
    _progress.dispose();
    super.dispose();
  }

  /// Runs or holds the progress timer to match the current pause state.
  void _sync() {
    if (!mounted) return;
    if (_paused) {
      if (_progress.isAnimating) _progress.stop();
    } else if (!_progress.isAnimating) {
      _progress.forward();
    }
  }

  void _go(int i) {
    if (_count < 2) return;
    final n = ((i % _count) + _count) % _count;
    if (n == _index) return;
    setState(() {
      _prev = _index;
      _index = n;
      _changed = true;
    });
    _progress.value = 0;
    _sync();
    _precacheNext();
  }

  void _setTouching(bool v) {
    _touching = v;
    _sync();
  }

  // Scroll offsets can change mid-layout, so measure after the frame.
  void _queueVisibility() {
    if (_visibilityQueued) return;
    _visibilityQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityQueued = false;
      if (mounted) _checkVisibility();
    });
  }

  /// Pauses auto-advance once less than half of the slider is on screen.
  void _checkVisibility() {
    final pos = _position;
    final box = context.findRenderObject();
    if (pos == null || box is! RenderBox || !box.attached || !box.hasSize) return;
    if (!pos.hasPixels || !pos.hasViewportDimension) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final h = box.size.height;
    final shown = math.min(top + h, pos.pixels + pos.viewportDimension) - math.max(top, pos.pixels);
    final visible = shown >= h * 0.5;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  void _precacheNext() {
    if (_count < 2) return;
    final url = AppConfig.resolveUrl(widget.dramas[(_index + 1) % _count].posterUrl);
    if (url.isEmpty) return;
    for (final w in const [_posterCacheWidth, _backdropCacheWidth]) {
      final ImageProvider provider =
          kIsWeb ? NetworkImage(url) : ResizeImage.resizeIfNeeded(w, null, CachedNetworkImageProvider(url));
      precacheImage(provider, context, onError: (_, _) {});
    }
  }

  void _play(Drama d) {
    Haptics.tap();
    context.push('/watch/${d.slug}/1', extra: d);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dramas.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    // The poster size and slide height of the website's phone layout.
    final posterH = width >= 640 ? 330.0 : 290.0;
    final top = widget.topInset + 8;
    final height = top + posterH + 226;
    final shown = <int>{if (_prev != _index && _prev < _count) _prev, _index};
    final swipe = _count > 1;
    return Semantics(
      container: true,
      child: Listener(
        onPointerDown: (_) => _setTouching(true),
        onPointerUp: (_) => _setTouching(false),
        onPointerCancel: (_) => _setTouching(false),
        child: GestureDetector(
          onHorizontalDragStart: swipe ? (_) => _dragDx = 0 : null,
          onHorizontalDragUpdate: swipe ? (d) => _dragDx += d.primaryDelta ?? 0 : null,
          onHorizontalDragEnd: swipe
              ? (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (_dragDx.abs() > 40 || v.abs() > 400) {
                    final toNext = _dragDx.abs() > 40 ? _dragDx < 0 : v < 0;
                    _go(toNext ? _index + 1 : _index - 1);
                  }
                }
              : null,
          child: ColoredBox(
            color: AppColors.bg,
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final i in shown)
                    _Slide(
                      key: ValueKey('hero-slide-$i'),
                      drama: widget.dramas[i],
                      active: i == _index,
                      immediate: !_changed,
                      posterHeight: posterH,
                      top: top,
                      label: context.l10n.heroSlide(i + 1, _count),
                      onPlay: () => _play(widget.dramas[i]),
                      onInfo: () => openDrama(context, widget.dramas[i]),
                    ),
                  if (_count > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: _Dots(
                        count: _count,
                        index: _index,
                        progress: _progress,
                        autoplay: _autoplay,
                        onTap: _go,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _posterCacheWidth = 600;
const _backdropCacheWidth = 200;

class _Slide extends StatefulWidget {
  const _Slide({
    super.key,
    required this.drama,
    required this.active,
    required this.immediate,
    required this.posterHeight,
    required this.top,
    required this.label,
    required this.onPlay,
    required this.onInfo,
  });

  final Drama drama;
  final bool active;
  final bool immediate;
  final double posterHeight;
  final double top;
  final String label;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide> with TickerProviderStateMixin {
  // Backdrop + poster cross-fade.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  // Copy: slides up after a 300 ms delay over 700 ms; leaves in 150 ms so
  // two titles never overlap mid-transition.
  late final AnimationController _copy = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    reverseDuration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fade, curve: _ease, reverseCurve: _ease.flipped);
  late final Animation<double> _copyAnim = CurvedAnimation(
    parent: _copy,
    curve: const Interval(0.3, 1, curve: _ease),
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.active) return;
    if (widget.immediate) {
      _fade.value = 1;
      _copy.value = 1;
    } else {
      _fade.forward();
      _copy.forward();
    }
  }

  @override
  void didUpdateWidget(_Slide old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active) {
      _fade.forward();
      _copy.forward();
    } else {
      _fade.reverse();
      _copy.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drama;
    final posterH = widget.posterHeight;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.active,
        child: ExcludeSemantics(
          excluding: !widget.active,
          child: Semantics(
            label: widget.label,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _Backdrop(url: d.posterUrl),
                ),
                Positioned(
                  top: widget.top,
                  left: 0,
                  right: 0,
                  height: posterH,
                  child: AnimatedBuilder(
                    animation: _fadeAnim,
                    builder: (_, child) {
                      final v = _fadeAnim.value;
                      return Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(40 * (1 - v), 0),
                          child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
                        ),
                      );
                    },
                    child: Center(
                      child: _HeroPoster(drama: d, height: posterH, onTap: widget.onInfo),
                    ),
                  ),
                ),
                Positioned(
                  top: widget.top + posterH + 20,
                  left: 16,
                  right: 16,
                  child: AnimatedBuilder(
                    animation: _copyAnim,
                    builder: (_, child) {
                      final v = _copyAnim.value;
                      return Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
                      );
                    },
                    child: _Copy(drama: d, onPlay: widget.onPlay, onInfo: widget.onInfo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The poster blown up, blurred and saturated, fading into the page.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg;
    return ExcludeSemantics(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterWash(url, opacity: AppColors.isDark ? 1 : 0.5, cacheWidth: _backdropCacheWidth),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [bg, bg.withValues(alpha: 0.4), bg.withValues(alpha: 0.1)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [bg, bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sharp 9:16 poster with rounded corners and a soft shadow.
class _HeroPoster extends StatelessWidget {
  const _HeroPoster({required this.drama, required this.height, required this.onTap});
  final Drama drama;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: height * 9 / 16,
        height: height,
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: Color(0xD9000000), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 30)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                image: true,
                label: drama.title,
                child: NetImage(drama.posterUrl, memCacheWidth: _posterCacheWidth),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.drama, required this.onPlay, required this.onInfo});
  final Drama drama;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = drama;
    final names = d.categories.isNotEmpty ? d.categories.map((c) => c.name) : d.tags;
    final genres = names.take(3).toList();
    final meta = TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3);
    final badge = d.badge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (badge != null && const {'hot', 'new', 'vip'}.contains(badge)) _HeroBadge(badge),
            Text(episodesLabel(context, d.totalEpisodes), style: meta),
            for (final g in genres)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(g, style: meta),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          d.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _PillButton(
                label: l.heroPlay,
                icon: Icons.play_arrow_rounded,
                primary: true,
                onTap: onPlay,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: _PillButton(
                label: l.heroMoreInfo,
                icon: Icons.info_outline_rounded,
                primary: false,
                onTap: onInfo,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hot / New / VIP pill, styled like the website hero badge.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge(this.badge);
  final String badge;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, ring) = switch (badge) {
      'new' => (context.l10n.badgeNew, Colors.white, Colors.black, null),
      'vip' => ('VIP', const Color(0xCC000000), Colors.white, const Color(0x4DFFFFFF)),
      _ => (context.l10n.badgeHot, AppColors.primary, Colors.white, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: ring == null ? null : Border.all(color: ring),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          height: 1.3,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.primary, required this.onTap});
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.text;
    final shape = StadiumBorder(
      side: primary ? BorderSide.none : BorderSide(color: AppColors.text.withValues(alpha: 0.15)),
    );
    final button = Material(
      color: primary ? AppColors.primary : AppColors.text.withValues(alpha: 0.1),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: primary ? 24 : 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!primary) return button;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
        boxShadow: [
          BoxShadow(color: Color(0xB3E90204), blurRadius: 26, spreadRadius: -8, offset: Offset(0, 10)),
        ],
      ),
      child: button,
    );
  }
}

/// Pill dots; the active one stretches and fills with the slide's progress.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.index,
    required this.progress,
    required this.autoplay,
    required this.onTap,
  });

  final int count;
  final int index;
  final Animation<double> progress;
  final bool autoplay;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == index,
            label: l.heroSlide(i + 1, count),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: _ease,
                      width: i == index ? 36 : 6,
                      height: 6,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        color: AppColors.text.withValues(alpha: i == index ? 0.25 : 0.35),
                      ),
                      child: i == index
                          ? AnimatedBuilder(
                              animation: progress,
                              builder: (_, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: autoplay ? progress.value : 1,
                                heightFactor: 1,
                                child: const ColoredBox(color: AppColors.primary),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
