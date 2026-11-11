import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/buttons.dart';
import 'video_surface.dart';

/// Plays [controller] rotated to landscape, immersive; restores portrait
/// and the normal system bars when closed.
Future<void> openFullScreenVideo(BuildContext context, VideoPlayerController controller) {
  Haptics.tap();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.normal,
    pageBuilder: (_, _, _) => Theme(data: AppTheme.video, child: FullScreenVideo(controller: controller)),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

class FullScreenVideo extends StatefulWidget {
  const FullScreenVideo({super.key, required this.controller});
  final VideoPlayerController controller;

  @override
  State<FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<FullScreenVideo> {
  bool _chrome = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _chrome = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    if (_chrome) _scheduleHide();
  }

  void _togglePlay() {
    final c = widget.controller;
    Haptics.light();
    c.value.isPlaying ? c.pause() : c.play();
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, v, _) => v.isInitialized
                    ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c))
                    : const CircularProgressIndicator(color: Colors.white70),
              ),
            ),
            IgnorePointer(
              ignoring: !_chrome,
              child: AnimatedOpacity(
                duration: AppMotion.normal,
                opacity: _chrome ? 1 : 0,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
                    Positioned(
                      top: pad.top + 12,
                      left: pad.left + 12,
                      child: GlassIconButton(
                        icon: Icons.fullscreen_exit_rounded,
                        tooltip: context.l10n.playerExitFullScreen,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Center(
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: c,
                        builder: (_, v, _) => GlassIconButton(
                          icon: v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 64,
                          onPressed: _togglePlay,
                        ),
                      ),
                    ),
                    Positioned(
                      left: pad.left + 24,
                      right: pad.right + 24,
                      bottom: pad.bottom + 12,
                      child: SizedBox(
                        height: 44,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: VideoProgressBar(controller: c),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
