import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../services/catalog_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/states.dart';
import 'episode_page.dart';
import 'episodes_sheet.dart';
import 'video_surface.dart';

/// Full-screen vertical episode player (swipe up/down between episodes).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.slug, this.episodeNumber = 1});

  final String slug;
  final int episodeNumber;

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
      final d = await context.read<CatalogService>().drama(widget.slug);
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
      showSnack(context, context.tr("That's the finale. Thanks for watching!"));
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
                : const Stack(children: [
                    Center(child: CircularProgressIndicator(color: Colors.white70)),
                    _TopBar(title: '', subtitle: ''),
                  ])
            : d.episodes.isEmpty
                ? Stack(children: [
                    StateMessage(
                      icon: Icons.video_library_outlined,
                      title: context.tr('Episodes coming soon'),
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
                        overlayBuilder: (context, controller) => _Overlay(
                          drama: d.drama,
                          episode: ep,
                          total: d.episodes.length,
                          controller: controller,
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
  });

  final Drama drama;
  final Episode episode;
  final int total;
  final VideoPlayerController? controller;
  final VoidCallback onEpisodes;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        _TopBar(title: drama.title, subtitle: context.tr('EP {n} / {total}', {'n': episode.number, 'total': total})),
        Positioned(
          right: 10,
          bottom: bottom + 110,
          child: Column(
            children: [
              FavoriteRailAction(drama: drama),
              RailAction(icon: Icons.video_library_rounded, label: context.tr('Episodes'), onTap: onEpisodes),
              RailAction(
                icon: Icons.reply_rounded,
                label: context.tr('Share'),
                onTap: () => shareDrama(drama, episode: episode.number),
              ),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('EP {n} · All {total} episodes', {'n': episode.number, 'total': total}),
                          style: text.labelMedium!.copyWith(color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
