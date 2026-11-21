import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/hls.dart';
import '../../core/video_source.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../services/player_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/production_in_progress.dart';
import '../../widgets/buttons.dart';
import 'fullscreen_video.dart';
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

  /// Builds the chrome (title, rail, progress) given the current controller
  /// and the episode's HLS renditions (empty until known / for non-HLS).
  final Widget Function(BuildContext context, VideoPlayerController? controller, List<HlsVariant> variants)
      overlayBuilder;

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  VideoPlayerController? _controller;

  /// Master URL from the play endpoint; the played URL may be a rendition.
  String? _url;
  List<HlsVariant> _variants = const [];
  int _quality = 0;
  late final SettingsState _settings;
  UnlockInfo? _locked;
  Object? _error;
  bool _comingSoon = false;
  int? _nextId;
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
    _settings = context.read<SettingsState>()..addListener(_onSettings);
    _lifecycle = AppLifecycleListener(
      onInactive: () => _controller?.pause(),
      onHide: () {
        _controller?.pause();
        _saveProgress();
      },
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
    _settings.removeListener(_onSettings);
    _lifecycle.dispose();
    _deactivate(disposing: true);
    super.dispose();
  }

  /// A new preferred quality switches the playing episode in place.
  void _onSettings() {
    if (!widget.active || _url == null || _settings.videoQuality == _quality) return;
    final c = _controller;
    _activate(resumeAt: c != null && c.value.isInitialized ? c.value.position : null);
  }

  Future<void> _activate({Duration? resumeAt}) async {
    _releaseController();
    final gen = ++_generation;
    _endedFired = false;
    setState(() {
      _loading = true;
      _error = null;
      _comingSoon = false;
    });
    try {
      if (_url == null) {
        final res = await _service.play(widget.episode.id);
        if (!mounted || gen != _generation) return;
        _locked = null;
        _nextId = res.nextEpisodeId;
        final url = AppConfig.resolveUrl(res.videoUrl);
        if (url.isEmpty) {
          // Video not ready yet (uploading / encoding). Leave _url null so the
          // next activation asks the API again.
          setState(() {
            _comingSoon = true;
            _loading = false;
          });
          return;
        }
        _url = url;
      }
      final master = _url!;
      fetchHlsVariants(master).then((v) {
        if (mounted && _url == master) setState(() => _variants = v);
      });
      _quality = _settings.videoQuality;
      final playUrl = await urlForQuality(master, _quality);
      if (!mounted || gen != _generation) return;
      final c = networkVideoController(
        playUrl,
        options: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = c;
      setState(() {});
      await c.initialize();
      // A newer activation / deactivation already released this controller.
      if (!mounted || gen != _generation) return;
      c.addListener(_onTick);
      if (resumeAt != null && resumeAt > Duration.zero) await c.seekTo(resumeAt);
      if (!mounted || gen != _generation) return;
      await c.play();
      // Get the next episode ready while this one plays, so swiping to it is instant.
      final next = _nextId;
      if (next != null) _service.prefetch(next);
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
          PlayerTint(url: poster),
          _LockedCard(
            episode: widget.episode,
            coins: _locked!.coinsRequired > 0 ? _locked!.coinsRequired : widget.drama.coinsPerEpisode,
            onUnlock: _openPaywall,
          ),
          widget.overlayBuilder(context, null, const []),
        ],
      );
    }

    if (_comingSoon) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PlayerTint(url: poster),
          ComingSoonCard(
            onRetry: () {
              _url = null;
              _activate();
            },
          ),
          widget.overlayBuilder(context, null, const []),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoSurface(
          controller: _controller,
          posterUrl: poster,
          loading: _loading,
          fit: widget.episode.isLandscape ? BoxFit.contain : null,
          dimPoster: _error != null,
        ),
        const VideoScrims(),
        if (widget.episode.isLandscape && _controller != null) _FullScreenButton(controller: _controller!),
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
                  label: context.l10n.actionRetry,
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
        widget.overlayBuilder(context, _controller, _variants),
      ],
    );
  }
}

/// "Full screen" pill under the letterboxed 16:9 video of landscape episodes.
class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final videoH = box.maxWidth * 9 / 16;
          return Stack(
            children: [
              Positioned(
                top: (box.maxHeight + videoH) / 2 + 10,
                right: 12,
                child: Material(
                  type: MaterialType.transparency,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => openFullScreenVideo(context, controller),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.playerFullScreen,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 30, color: Colors.white70),
            const SizedBox(height: 14),
            Text(l.lockedTitle(episode.number), style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              l.lockedMessage(coins),
              style: text.bodyMedium!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PillButton(label: l.unlockEpisode, onPressed: onUnlock),
          ],
        ),
      ),
    );
  }
}

/// Shown when the episode exists but its video is still being prepared
/// (the play endpoint returned a null `video_url`).
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProductionScene(width: 240),
            const SizedBox(height: 18),
            Text(l.videoComingSoonTitle, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              l.videoComingSoonMessage,
              style: text.bodyMedium!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const PulsingDots(),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              PillButton(
                label: l.actionRefresh,
                icon: Icons.refresh_rounded,
                height: 42,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
