import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
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
  PlayResult? _play;

  /// Index into [_play]'s playable sources (0 = Auto / adaptive).
  int _sourceIndex = 0;

  /// Position to seek to after (re)initialising: resume point or the position before a quality switch.
  Duration? _pendingSeek;
  UnlockInfo? _locked;

  // Analytics (SPEC §8.3): wall-clock time actually spent playing, reported in heartbeats.
  final _watch = Stopwatch();
  int _reportedSeconds = 0;
  bool _startSent = false;
  bool _wasPlaying = false;
  Timer? _heartbeat;
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
        _play = res;
        _sourceIndex = 0;
        _startSent = false;
        _reportedSeconds = 0;
        _watch.reset();
        _url = AppConfig.resolveUrl(res.playable.first.url);
        if (res.resumeSeconds > 0) _pendingSeek = Duration(seconds: res.resumeSeconds);
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
      final seek = _pendingSeek;
      _pendingSeek = null;
      if (seek != null && seek < c.value.duration - const Duration(seconds: 3)) {
        await c.seekTo(seek);
      }
      c.addListener(_onTick);
      await c.play();
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _event('heartbeat'));
      if (!_startSent) {
        _startSent = true;
        _event('start');
      }
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
      if (_play != null) _event('error', errorCode: e is ApiException ? e.code : 'playback_failed');
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
    _heartbeat?.cancel();
    _event('pause');
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
    if (v.isPlaying && !_watch.isRunning) _watch.start();
    if (!v.isPlaying && _watch.isRunning) _watch.stop();
    // Paused by the viewer: save the position so "Endelea kutazama" is exact.
    if (_wasPlaying && !v.isPlaying && v.position < v.duration - const Duration(milliseconds: 300)) {
      _saveProgress();
      _event('pause');
    }
    _wasPlaying = v.isPlaying;
    if (!_endedFired &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        !v.isPlaying &&
        v.position >= v.duration - const Duration(milliseconds: 300)) {
      _endedFired = true;
      _saveProgress();
      _event('complete');
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

  /// Sends one analytics event for this playback (best-effort).
  void _event(String type, {String? errorCode, String? quality}) {
    final play = _play;
    if (play == null || play.sessionId.isEmpty) return;
    final c = _controller;
    final v = c?.value;
    final watched = _watch.elapsed.inSeconds - _reportedSeconds;
    _reportedSeconds = _watch.elapsed.inSeconds;
    _service.sendEvents([
      {
        'session_id': play.sessionId,
        'episode_id': widget.episode.id,
        'type': type,
        if (v != null && v.isInitialized) 'position_seconds': v.position.inSeconds,
        if (v != null && v.isInitialized && v.duration > Duration.zero) 'duration_seconds': v.duration.inSeconds,
        'watched_seconds': watched.clamp(0, 120),
        'quality': ?quality,
        'error_code': ?errorCode,
      },
    ]);
  }

  /// Quality picker: switch to another source and continue from the same position.
  Future<void> _chooseQuality() async {
    final play = _play;
    if (play == null) return;
    final sources = play.playable;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(ctx.tr('Video quality'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            for (var i = 0; i < sources.length; i++)
              ListTile(
                title: Text(
                  sources[i].isAuto ? ctx.tr('Auto (adjusts to your network)') : sources[i].label,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: i == _sourceIndex ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _sourceIndex || !mounted) return;
    final c = _controller;
    _pendingSeek = c != null && c.value.isInitialized ? c.value.position : null;
    _sourceIndex = picked;
    _url = AppConfig.resolveUrl(sources[picked].url);
    _event('quality', quality: sources[picked].quality);
    _activate();
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
      _play = null;
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
            vipOnly: _locked!.vipOnly,
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
                    context.tr(errorMessage(_error!)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: context.tr('Retry'),
                  icon: Icons.refresh_rounded,
                  height: 42,
                  onPressed: () {
                    // Retry keeps the position the viewer had reached.
                    final c = _controller;
                    if (c != null && c.value.isInitialized) _pendingSeek = c.value.position;
                    _url = null;
                    _activate();
                  },
                ),
              ],
            ),
          ),
        widget.overlayBuilder(context, _controller),
        if ((_play?.playable.length ?? 0) > 1)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            right: 10,
            child: GlassIconButton(
              icon: Icons.high_quality_rounded,
              tooltip: context.tr('Video quality'),
              onPressed: _chooseQuality,
            ),
          ),
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
  const _LockedCard({required this.episode, required this.coins, required this.onUnlock, this.vipOnly = false});
  final Episode episode;
  final int coins;
  final bool vipOnly;
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
            Text(context.tr('Episode {n} is locked', {'n': episode.number}), style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              vipOnly
                  ? context.tr('Join VIP to watch this series.')
                  : context.tr('Unlock it for {coins} coins or join VIP to watch everything.', {'coins': coins}),
              style: text.bodyMedium!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PillButton(label: context.tr('Unlock episode'), icon: Icons.lock_open_rounded, onPressed: onUnlock),
          ],
        ),
      ),
    );
  }
}
