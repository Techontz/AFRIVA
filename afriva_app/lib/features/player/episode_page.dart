import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../services/player_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';
import 'paywall_sheet.dart';
import 'video_surface.dart';

/// One page of the vertical player. Fetches the play URL when it becomes
/// active, owns its [VideoPlayerController] and saves progress.
class EpisodePage extends StatefulWidget {
  const EpisodePage({
    super.key,
    required this.drama,
    required this.episode,
    required this.active,
    required this.onEnded,
    required this.overlayBuilder,
    this.autoOpenPaywall = true,
  });

  final Drama drama;
  final Episode episode;
  final bool active;
  final VoidCallback onEnded;
  final bool autoOpenPaywall;

  /// Builds the chrome (title, rail, progress) given the current controller.
  final Widget Function(BuildContext context, VideoPlayerController? controller) overlayBuilder;

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  VideoPlayerController? _controller;
  String? _url;
  UnlockInfo? _locked;
  Object? _error;
  bool _loading = false;
  bool _endedFired = false;
  bool _paywallShown = false;
  int _generation = 0;
  Timer? _progressTimer;
  late final AppLifecycleListener _lifecycle;
  late final PlayerService _service;

  @override
  void initState() {
    super.initState();
    _service = context.read<PlayerService>();
    _lifecycle = AppLifecycleListener(
      onInactive: () => _controller?.pause(),
      onHide: () => _controller?.pause(),
    );
    if (widget.active) _activate();
  }

  @override
  void didUpdateWidget(covariant EpisodePage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      widget.active ? _activate() : _deactivate();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _deactivate(disposing: true);
    super.dispose();
  }

  Future<void> _activate() async {
    _releaseController();
    final gen = ++_generation;
    _endedFired = false;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_url == null) {
        final res = await _service.play(widget.episode.id);
        if (!mounted || gen != _generation) return;
        _url = AppConfig.resolveUrl(res.videoUrl);
        _locked = null;
      }
      final c = VideoPlayerController.networkUrl(
        Uri.parse(_url!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = c;
      setState(() {});
      await c.initialize();
      // A newer activation / deactivation already released this controller.
      if (!mounted || gen != _generation) return;
      c.addListener(_onTick);
      await c.play();
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
      setState(() => _loading = false);
    } on EpisodeLockedException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _locked = e.info;
        _loading = false;
      });
      if (widget.autoOpenPaywall && !_paywallShown) {
        _paywallShown = true;
        _openPaywall();
      }
    } catch (e) {
      if (!mounted || gen != _generation) return;
      final old = _controller;
      _controller = null;
      old?.dispose();
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _deactivate({bool disposing = false}) {
    _generation++;
    _progressTimer?.cancel();
    _releaseController();
    if (!disposing && mounted) {
      setState(() => _loading = false);
    }
  }

  void _releaseController() {
    _saveProgress();
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onTick);
      c.dispose();
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (!_endedFired &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        !v.isPlaying &&
        v.position >= v.duration - const Duration(milliseconds: 300)) {
      _endedFired = true;
      _saveProgress();
      widget.onEnded();
    }
  }

  void _saveProgress() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final secs = c.value.position.inSeconds;
    if (secs <= 0) return;
    _service.saveProgress(widget.episode.id, secs);
  }

  Future<void> _openPaywall() async {
    final info = _locked;
    if (info == null) return;
    final result = await showPaywallSheet(
      context,
      drama: widget.drama,
      episode: widget.episode,
      info: info,
    );
    if (!mounted) return;
    if (result != null && widget.active) {
      _url = null;
      _activate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.episode.thumbnailUrl.isNotEmpty
        ? widget.episode.thumbnailUrl
        : widget.drama.posterUrl;

    if (_locked != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _LockedBackdrop(url: poster),
          _LockedCard(
            episode: widget.episode,
            coins: _locked!.coinsRequired > 0 ? _locked!.coinsRequired : widget.drama.coinsPerEpisode,
            onUnlock: _openPaywall,
          ),
          widget.overlayBuilder(context, null),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoSurface(controller: _controller, posterUrl: poster, loading: _loading),
        const VideoScrims(),
        if (_error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 40),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    errorMessage(_error!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  height: 42,
                  onPressed: () {
                    _url = null;
                    _activate();
                  },
                ),
              ],
            ),
          ),
        widget.overlayBuilder(context, _controller),
      ],
    );
  }
}

class _LockedBackdrop extends StatelessWidget {
  const _LockedBackdrop({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: NetImage(url, memCacheWidth: 360),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        ],
      );
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.episode, required this.coins, required this.onUnlock});
  final Episode episode;
  final int coins;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
              child: const Icon(Icons.lock_rounded, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('Episode ${episode.number} is locked', style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Unlock it for $coins coins or join VIP to watch everything.',
              style: text.bodyMedium!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PillButton(label: 'Unlock episode', icon: Icons.lock_open_rounded, onPressed: onUnlock),
          ],
        ),
      ),
    );
  }
}
