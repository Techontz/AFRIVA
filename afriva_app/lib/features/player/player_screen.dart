import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../core/hls.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../services/catalog_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/states.dart';
import 'episode_page.dart';
import 'episodes_sheet.dart';
import 'quality_sheet.dart';
import 'video_surface.dart';

/// Full-screen vertical episode player (swipe up/down between episodes).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.slug, this.episodeNumber = 1, this.initialDrama});

  final String slug;
  final int episodeNumber;

  /// Known when opened from a poster, so its art shows while loading.
  final Drama? initialDrama;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  DramaDetail? _detail;
  Object? _error;
  PageController? _pc;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await context.read<CatalogService>().drama(widget.slug, maxAge: const Duration(minutes: 1));
      if (!mounted) return;
      final idx = d.indexOfNumber(widget.episodeNumber);
      _pc?.dispose();
      setState(() {
        _detail = d;
        _index = idx;
        _pc = PageController(initialPage: idx);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _goTo(int index, {bool animate = true}) {
    final d = _detail;
    final pc = _pc;
    if (d == null || pc == null || index < 0 || index >= d.episodes.length) return;
    if (animate && (index - _index).abs() == 1) {
      pc.animateToPage(index, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      pc.jumpToPage(index);
    }
  }

  void _onEnded() {
    final d = _detail;
    if (d == null) return;
    if (!context.read<SettingsState>().autoplayNext) return;
    if (_index < d.episodes.length - 1) {
      _goTo(_index + 1);
    } else {
      showSnack(context, context.l10n.playerFinale);
    }
  }

  Future<void> _openEpisodes() async {
    final d = _detail;
    if (d == null) return;
    final ep = await showEpisodesSheet(
      context,
      drama: d.drama,
      episodes: d.episodes,
      currentNumber: d.episodes[_index].number,
    );
    if (ep != null && mounted) _goTo(d.episodes.indexOf(ep), animate: false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: afrivaVideoOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: d == null
            ? _error != null
                ? Stack(children: [
                    ErrorState(error: _error!, onRetry: _load),
                    _TopBar(title: '', subtitle: ''),
                  ])
                : Stack(fit: StackFit.expand, children: [
                    VideoSurface(controller: null, posterUrl: widget.initialDrama?.posterUrl, loading: true),
                    _TopBar(title: widget.initialDrama?.title ?? '', subtitle: ''),
                  ])
            : d.episodes.isEmpty
                ? Stack(children: [
                    StateMessage(
                      icon: Icons.video_library_outlined,
                      title: context.l10n.episodesComingSoon,
                    ),
                    _TopBar(title: d.drama.title, subtitle: ''),
                  ])
                : PageView.builder(
                    controller: _pc,
                    scrollDirection: Axis.vertical,
                    itemCount: d.episodes.length,
                    onPageChanged: (i) {
                      Haptics.light();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) {
                      final ep = d.episodes[i];
                      return EpisodePage(
                        key: ValueKey('ep-${ep.id}'),
                        drama: d.drama,
                        episode: ep,
                        active: i == _index,
                        onEnded: _onEnded,
                        overlayBuilder: (context, controller, variants) => _Overlay(
                          drama: d.drama,
                          episode: ep,
                          total: d.episodes.length,
                          controller: controller,
                          variants: variants,
                          onEpisodes: _openEpisodes,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.drama,
    required this.episode,
    required this.total,
    required this.controller,
    required this.onEpisodes,
    this.variants = const [],
  });

  final Drama drama;
  final Episode episode;
  final int total;
  final VideoPlayerController? controller;
  final List<HlsVariant> variants;
  final VoidCallback onEpisodes;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Stack(
      children: [
        _TopBar(title: drama.title, subtitle: l.playerEpisodeOf(episode.number, total)),
        Positioned(
          right: 10,
          bottom: bottom + 110,
          child: Column(
            children: [
              FavoriteRailAction(drama: drama),
              RailAction(icon: Icons.video_library_rounded, label: l.episodesTitle, onTap: onEpisodes),
              RailAction(
                icon: Icons.reply_rounded,
                label: l.actionShare,
                onTap: () => shareDrama(drama, episode: episode.number),
              ),
              if (variants.isNotEmpty) _QualityAction(variants: variants),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom + 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 64),
                child: Text(
                  episode.title.isNotEmpty ? episode.title : drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
              ),
              if (drama.synopsis.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 64),
                  child: Text(
                    drama.synopsis,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onEpisodes,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.playerAllEpisodes(episode.number, total),
                          style: text.labelMedium!.copyWith(
                            color: Colors.white,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 44,
                child: controller == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: VideoProgressBar(controller: controller!),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rail button showing the active quality ("Auto" / "720p"); opens the picker.
class _QualityAction extends StatelessWidget {
  const _QualityAction({required this.variants});
  final List<HlsVariant> variants;

  @override
  Widget build(BuildContext context) {
    final q = context.select<SettingsState, int>((s) => s.videoQuality);
    final label = pickVariant(variants, q)?.label ?? context.l10n.qualityAuto;
    return RailAction(
      icon: Icons.tune_rounded,
      label: label,
      onTap: () => showQualitySheet(context, variants: variants),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 4,
      left: 8,
      right: 8,
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                    )),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: text.labelSmall!.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
