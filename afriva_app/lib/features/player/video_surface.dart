import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/net_image.dart';

/// Renders a [VideoPlayerController] full-bleed with tap-to-pause and a
/// poster fallback while buffering.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.controller,
    this.posterUrl,
    this.loading = false,
  });

  final VideoPlayerController? controller;
  final String? posterUrl;
  final bool loading;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _showPausedIcon = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    Haptics.light();
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _showPausedIcon = true);
    } else {
      if (c.value.position >= c.value.duration && c.value.duration > Duration.zero) {
        c.seekTo(Duration.zero);
      }
      c.play();
      setState(() => _showPausedIcon = false);
    }
    _pulse.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (widget.posterUrl != null && (c == null || !c.value.isInitialized))
            Opacity(opacity: 0.55, child: NetImage(widget.posterUrl, memCacheWidth: 720)),
          if (c != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) {
                if (!v.isInitialized) return const SizedBox.shrink();
                final ar = v.aspectRatio;
                // Vertical content fills the screen; landscape content is letterboxed.
                return FittedBox(
                  fit: ar < 1 ? BoxFit.cover : BoxFit.contain,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: v.size.width,
                    height: v.size.height,
                    child: VideoPlayer(c),
                  ),
                );
              },
            ),
          if (c != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) {
                final buffering = widget.loading || !v.isInitialized || (v.isBuffering && v.isPlaying);
                return Center(
                  child: AnimatedOpacity(
                    duration: AppMotion.normal,
                    opacity: buffering ? 1 : 0,
                    child: const SizedBox.square(
                      dimension: 38,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white70),
                    ),
                  ),
                );
              },
            )
          else if (widget.loading)
            const Center(
              child: SizedBox.square(
                dimension: 38,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white70),
              ),
            ),
          if (c != null)
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) {
                  final paused = v.isInitialized && !v.isPlaying && _showPausedIcon;
                  return IgnorePointer(
                    child: AnimatedScale(
                      scale: paused ? 1 : 1.4,
                      duration: AppMotion.normal,
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: paused ? 1 : 0,
                        duration: AppMotion.normal,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Slim scrubbable progress bar with time labels while dragging.
class VideoProgressBar extends StatefulWidget {
  const VideoProgressBar({super.key, required this.controller});
  final VideoPlayerController controller;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double? _drag;
  bool _wasPlaying = false;

  void _seekTo(double fraction) {
    final d = widget.controller.value.duration;
    widget.controller.seekTo(d * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      double frac(Offset local) => (local.dx / box.maxWidth).clamp(0.0, 1.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          _wasPlaying = widget.controller.value.isPlaying;
          widget.controller.pause();
          setState(() => _drag = frac(d.localPosition));
        },
        onHorizontalDragUpdate: (d) => setState(() => _drag = frac(d.localPosition)),
        onHorizontalDragEnd: (_) {
          if (_drag != null) _seekTo(_drag!);
          if (_wasPlaying) widget.controller.play();
          setState(() => _drag = null);
        },
        onTapUp: (d) {
          Haptics.tap();
          _seekTo(frac(d.localPosition));
        },
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: widget.controller,
          builder: (context, v, _) {
            final total = v.duration.inMilliseconds;
            final played = total > 0 ? v.position.inMilliseconds / total : 0.0;
            final buffered = total > 0 && v.buffered.isNotEmpty
                ? v.buffered.last.end.inMilliseconds / total
                : 0.0;
            final shown = _drag ?? played.clamp(0.0, 1.0);
            final dragging = _drag != null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: dragging ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${Fmt.duration(v.duration * shown)} / ${Fmt.duration(v.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        height: dragging ? 5 : 2.5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: buffered.clamp(0.0, 1.0),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          height: dragging ? 5 : 2.5,
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: shown,
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          height: dragging ? 5 : 2.5,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (box.maxWidth * shown) - (dragging ? 8 : 5),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          width: dragging ? 16 : 10,
                          height: dragging ? 16 : 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

/// Dark gradients at top and bottom so overlays stay legible on bright video.
class VideoScrims extends StatelessWidget {
  const VideoScrims({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: Column(
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Spacer(),
            SizedBox(
              height: 300,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
