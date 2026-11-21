import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/config.dart';
import '../../core/hls.dart';
import '../../core/haptics.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/video_source.dart';
import '../../l10n/l10n.dart';
import '../../models/episode.dart';
import '../../models/home.dart';
import '../../services/catalog_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/states.dart';
import '../player/episodes_sheet.dart';
import '../player/video_surface.dart';

/// TikTok-style vertical feed of episode 1 of each drama.
class ForYouScreen extends StatefulWidget {
  const ForYouScreen({super.key});

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  List<FeedItem>? _items;
  Object? _error;
  int _index = 0;
  final _pc = PageController();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another tab is selected or a route covers the shell.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<CatalogService>().feed();
      if (mounted) {
        setState(() {
          _items = items;
          _index = 0;
        });
        if (_pc.hasClients) _pc.jumpToPage(0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    Widget body;
    if (items == null && _error == null) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white70));
    } else if (items == null) {
      body = ErrorState(error: _error!, onRetry: _load);
    } else if (items.isEmpty) {
      body = StateMessage(
        icon: Icons.play_circle_outline_rounded,
        title: context.l10n.feedEmptyTitle,
        message: context.l10n.feedEmptyMessage,
        actionLabel: context.l10n.actionRefresh,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.primary,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: _load,
        child: PageView.builder(
          controller: _pc,
          scrollDirection: Axis.vertical,
          // Keeps the next page built so its video can load before the swipe.
          allowImplicitScrolling: true,
          itemCount: items.length,
          onPageChanged: (i) {
            Haptics.light();
            setState(() => _index = i);
          },
          itemBuilder: (context, i) => _FeedPage(
            key: ValueKey('feed-${items[i].drama.id}-${items[i].episode.id}'),
            item: items[i],
            active: _visible && i == _index,
            preload: _visible && i == _index + 1,
          ),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: afrivaVideoOverlayStyle,
      child: ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  context.l10n.navForYouTitle,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
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

class _FeedPage extends StatefulWidget {
  const _FeedPage({super.key, required this.item, required this.active, this.preload = false});
  final FeedItem item;
  final bool active;

  /// The next page: load the video paused so it starts instantly when swiped to.
  final bool preload;

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _failed = false;
  bool _resolving = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onInactive: () => _c?.pause(), onHide: () => _c?.pause());
    if (widget.active || widget.preload) _start();
  }

  @override
  void didUpdateWidget(covariant _FeedPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (widget.active) {
        _start();
      } else {
        _c?.pause();
      }
    } else if (widget.preload && !old.preload) {
      _start();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    final c = _c;
    _c = null;
    c?.dispose();
    super.dispose();
  }

  bool get _comingSoon => AppConfig.resolveUrl(widget.item.episode.videoUrl).isEmpty;

  Future<void> _start() async {
    if (_c != null) {
      if (_c!.value.isInitialized && widget.active) _c!.play();
      return;
    }
    final master = AppConfig.resolveUrl(widget.item.episode.videoUrl);
    if (master.isEmpty || _resolving) return;
    _resolving = true;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final url = await urlForQuality(master, context.read<SettingsState>().videoQuality);
    _resolving = false;
    if (!mounted || _c != null) return;
    final c = networkVideoController(url);
    setState(() => _c = c);
    try {
      await c.initialize();
      // Disposed (scrolled away / feed refreshed) while initializing.
      if (!mounted || !identical(_c, c)) return;
      await c.setLooping(true);
      if (!mounted || !identical(_c, c)) return;
      // Swiped here while it was loading in the background: play now.
      if (widget.active) await c.play();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted || !identical(_c, c)) return;
      setState(() {
        _loading = false;
        _failed = true;
        _c = null;
      });
      c.dispose();
    }
  }

  void _watchFull({int ep = 1}) {
    Haptics.medium();
    _c?.pause();
    context.push('/watch/${widget.item.drama.slug}/$ep');
  }

  Future<void> _episodes() async {
    _c?.pause();
    final catalog = context.read<CatalogService>();
    try {
      final detail = await catalog.drama(widget.item.drama.slug, maxAge: const Duration(minutes: 1));
      if (!mounted) return;
      final Episode? ep = await showEpisodesSheet(
        context,
        drama: detail.drama,
        episodes: detail.episodes,
        currentNumber: widget.item.episode.number,
      );
      if (ep != null && mounted) _watchFull(ep: ep.number);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.feedEpisodesError, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.item.drama;
    final text = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoSurface(
          controller: _c,
          posterUrl: widget.item.episode.thumbnailUrl.isNotEmpty
              ? widget.item.episode.thumbnailUrl
              : d.posterUrl,
          loading: _loading,
          fit: widget.item.episode.isLandscape ? BoxFit.contain : null,
          dimPoster: _failed,
        ),
        const VideoScrims(),
        if (_comingSoon)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.videoComingSoonBadge,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        if (_failed)
          Center(
            child: TextButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(context.l10n.tapToRetry, style: const TextStyle(color: Colors.white)),
            ),
          ),
        Positioned(
          right: 10,
          bottom: bottom + 120,
          child: Column(
            children: [
              FavoriteRailAction(drama: d),
              RailAction(icon: Icons.video_library_rounded, label: context.l10n.episodesTitle, onTap: _episodes),
              RailAction(icon: Icons.reply_rounded, label: context.l10n.actionShare, onTap: () => shareDrama(d)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: bottom + 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (d.badge != null) ...[
                    DramaBadge(d.badge!, small: true),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium!.copyWith(
                        fontSize: 18,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                d.synopsis,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in d.chips)
                    Text('#$c', style: text.labelMedium!.copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _watchFull,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.feedWatchFullSeries(d.totalEpisodes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: _c == null
                    ? null
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: VideoProgressBar(controller: _c!),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
