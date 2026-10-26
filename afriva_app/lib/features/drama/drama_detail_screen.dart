import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/episode_grid.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/net_image.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'report_sheet.dart';
import 'trailer_player.dart';

class DramaDetailScreen extends StatefulWidget {
  const DramaDetailScreen({super.key, required this.slug, this.initial, this.heroTag});

  final String slug;
  final Drama? initial;
  final String? heroTag;

  @override
  State<DramaDetailScreen> createState() => _DramaDetailScreenState();
}

class _DramaDetailScreenState extends State<DramaDetailScreen> {
  DramaDetail? _detail;
  Object? _error;
  bool _synopsisOpen = false;
  final _scroll = ScrollController();
  final _collapsed = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _collapsed.value = _scroll.offset > 220);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await context.read<CatalogService>().drama(widget.slug);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _play(int number) {
    Haptics.medium();
    context.push('/watch/${widget.slug}/$number').then((_) {
      // Unlock state may have changed while watching.
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final drama = _detail?.drama ?? widget.initial;
    if (drama == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ErrorState(error: _error!, onRetry: _load)
            : const _DetailSkeleton(),
      );
    }
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final backdropH = size.width * 0.78;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _collapsed,
          builder: (_, collapsed, _) => AnimatedContainer(
            duration: AppMotion.normal,
            color: collapsed ? AppColors.bg.withValues(alpha: 0.96) : Colors.transparent,
            child: AppBar(
              backgroundColor: Colors.transparent,
              // Light icons over the backdrop; dark once the white bar shows.
              systemOverlayStyle: collapsed ? afrivaLightOverlayStyle : afrivaOverlayStyle,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
              ),
              title: AnimatedOpacity(
                duration: AppMotion.normal,
                opacity: collapsed ? 1 : 0,
                child: Text(drama.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GlassIconButton(
                    icon: Icons.flag_outlined,
                    tooltip: context.tr('Report'),
                    onPressed: () => showReportSheet(context, drama),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GlassIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: context.tr('Share'),
                    onPressed: () => shareDrama(drama),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        edgeOffset: topPad + kToolbarHeight,
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: backdropH + 120,
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: 120,
                      child: NetImage(drama.backdropOrPoster, memCacheWidth: 1280),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.0),
                              AppColors.bg.withValues(alpha: 0.85),
                              AppColors.bg,
                            ],
                            stops: const [0, 0.3, 0.62, 0.78],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 118,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadii.poster),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
                                ],
                              ),
                              child: Poster(drama: drama, heroTag: widget.heroTag, showEpisodes: false),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(drama.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.headlineSmall!.copyWith(height: 1.12)),
                                const SizedBox(height: 8),
                                DefaultTextStyle(
                                  style: text.labelMedium!.copyWith(color: AppColors.textMuted),
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (drama.totalEpisodes > 0) Text(context.tr('{n} episodes', {'n': drama.totalEpisodes})),
                                      if (drama.totalDurationSeconds > 0)
                                        Text(_runtime(context, drama.totalDurationSeconds)),
                                      if (drama.ageRating != null) _AgeRating(drama.ageRating!),
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.local_fire_department_rounded,
                                            size: 14, color: AppColors.primary),
                                        const SizedBox(width: 2),
                                        Text(Fmt.compact(drama.views)),
                                      ]),
                                      if (drama.badge != null) DramaBadge(drama.badge!, small: true),
                                    ],
                                  ),
                                ),
                                if (drama.company != null) ...[
                                  const SizedBox(height: 6),
                                  Text(context.tr('by {name}', {'name': drama.company!.name}),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelSmall!.copyWith(color: AppColors.textDim)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(children: [
                if (drama.categories.isNotEmpty || drama.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in drama.categories) TagChip(c.name),
                      for (final t in drama.tags) TagChip(t),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: context.tr('Play EP 1'),
                        icon: Icons.play_arrow_rounded,
                        expand: true,
                        onPressed: () => _play(_detail?.episodes.firstOrNull?.number ?? 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MyListButton(drama: drama),
                  ],
                ),
                if ((drama.trailerUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  PillButton(
                    label: context.tr('Watch trailer'),
                    icon: Icons.movie_creation_outlined,
                    secondary: true,
                    expand: true,
                    height: 44,
                    onPressed: () => showTrailer(context, url: drama.trailerUrl!, title: drama.title),
                  ),
                ],
                const SizedBox(height: 18),
                if (drama.synopsis.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _synopsisOpen = !_synopsisOpen),
                    child: AnimatedSize(
                      duration: AppMotion.slow,
                      curve: AppMotion.curve,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drama.synopsis,
                            maxLines: _synopsisOpen ? null : 3,
                            overflow: _synopsisOpen ? null : TextOverflow.ellipsis,
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(context.tr(_synopsisOpen ? 'Show less' : 'Read more'),
                              style: text.labelMedium!.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
            ..._episodesSection(drama),
            ..._relatedSection(),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _episodesSection(Drama drama) {
    final detail = _detail;
    final header = SliverToBoxAdapter(
      child: SectionHeader(
        title: context.tr('Episodes'),
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      ),
    );
    if (detail == null) {
      return [
        header,
        SliverToBoxAdapter(
          child: _error != null
              ? ErrorState(error: _error!, onRetry: _load, compact: true)
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Skeleton(child: SkeletonBox(height: 160, radius: 12)),
                ),
        ),
      ];
    }
    if (detail.episodes.isEmpty) {
      return [
        header,
        SliverToBoxAdapter(
          child: StateMessage(
            icon: Icons.video_library_outlined,
            title: context.tr('Episodes coming soon'),
            compact: true,
          ),
        ),
      ];
    }
    final isVip = context.select<AuthState, bool>((a) => a.isVip);
    // Scope §02: say up front which episodes are free and what the rest cost.
    final then = drama.isVipOnly
        ? context.tr('then VIP only')
        : drama.accessMode == 'coins_only'
            ? context.tr('then {coins} coins per episode', {'coins': drama.coinsPerEpisode})
            : context.tr('then {coins} coins per episode or VIP', {'coins': drama.coinsPerEpisode});
    final freeInfo = drama.freeEpisodes > 0
        ? '${context.tr('Episodes 1-{free} are free', {'free': drama.freeEpisodes})} · $then'
        : null;
    return [
      header,
      if (freeInfo != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const CoinIcon(size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(freeInfo, style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: EpisodeGrid(
            episodes: detail.episodes,
            isVip: isVip,
            onTap: (e) => _play(e.number),
          ),
        ),
      ),
    ];
  }

  List<Widget> _relatedSection() {
    final related = _detail?.related ?? const <Drama>[];
    if (related.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: SectionHeader(title: context.tr('You may also like'))),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: posterGridDelegate,
          itemCount: related.length.clamp(0, 9),
          itemBuilder: (_, i) => PosterCard(drama: related[i], heroScope: 'related-${widget.slug}'),
        ),
      ),
    ];
  }
}

String _runtime(BuildContext context, int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return context.tr('{n} min', {'n': minutes});
  return context.tr('{h} h {m} min', {'h': minutes ~/ 60, 'm': minutes % 60});
}

/// Age rating (alama ya umri), e.g. "13+" or "Wote".
class _AgeRating extends StatelessWidget {
  const _AgeRating(this.rating);
  final String rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textMuted),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(rating == 'all' ? context.tr('All ages') : rating,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _MyListButton extends StatelessWidget {
  const _MyListButton({required this.drama});
  final Drama drama;

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>().contains(drama);
    return AnimatedContainer(
      duration: AppMotion.normal,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: fav ? AppColors.primary : AppColors.surface),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: () => toggleFavorite(context, drama),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.normal,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    fav ? Icons.check_rounded : Icons.add_rounded,
                    key: ValueKey(fav),
                    color: fav ? AppColors.primary : AppColors.text,
                  ),
                ),
                const SizedBox(width: 6),
                Text(context.tr('Favorite'),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 118, child: AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox())),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 22),
                      SizedBox(height: 8),
                      SkeletonBox(height: 14, width: 120),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            SkeletonBox(height: 50, radius: 25),
            SizedBox(height: 20),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(height: 12, width: 200),
            SizedBox(height: 28),
            SkeletonBox(height: 180, radius: 12),
          ],
        ),
      );
}
