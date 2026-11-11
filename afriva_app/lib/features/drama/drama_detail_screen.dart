import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
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
    _scroll.addListener(() => _collapsed.value = _scroll.offset > 300);
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
    context.push('/watch/${widget.slug}/$number', extra: _detail?.drama ?? widget.initial).then((_) {
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
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _collapsed,
          builder: (_, collapsed, _) => AnimatedContainer(
            duration: AppMotion.normal,
            color: collapsed ? AppColors.bg : Colors.transparent,
            child: AppBar(
              backgroundColor: Colors.transparent,
              systemOverlayStyle: afrivaLightOverlayStyle,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.text),
                onPressed: () => context.pop(),
              ),
              title: AnimatedOpacity(
                duration: AppMotion.normal,
                opacity: collapsed ? 1 : 0,
                child: Text(drama.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              ),
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
            SliverToBoxAdapter(child: _hero(drama, topPad)),
            ..._episodesSection(drama),
            ..._relatedSection(),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32)),
          ],
        ),
      ),
    );
  }

  /// Artwork-tinted hero: centred poster, title, quiet meta, Play first.
  Widget _hero(Drama drama, double topPad) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final meta = TextStyle(fontSize: 14, color: AppColors.textMuted);
    final genres = drama.categories.map((c) => c.name).toList();
    final firstEpisode = _detail?.episodes.firstOrNull?.number ?? 1;
    const dot = Text('·');
    return Stack(
      children: [
        Positioned.fill(child: PosterWash(drama.posterUrl, opacity: AppColors.isDark ? 0.7 : 0.4)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bg.withValues(alpha: 0.3),
                  AppColors.bg.withValues(alpha: 0.7),
                  AppColors.bg,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, topPad + kToolbarHeight + 4, 16, 10),
          child: Column(
            children: [
              SizedBox(
                width: 148,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20))],
                  ),
                  child: Poster(drama: drama, heroTag: widget.heroTag, radius: 18, cacheWidth: 480),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                drama.title,
                textAlign: TextAlign.center,
                style: text.headlineSmall!.copyWith(fontSize: 26, height: 1.1),
              ),
              const SizedBox(height: 10),
              DefaultTextStyle(
                style: meta,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (drama.badge != null) ...[DramaBadge(drama.badge!), dot],
                    Text(episodesLabel(context, drama.totalEpisodes)),
                    dot,
                    Text(l.viewsCount(Fmt.compact(drama.views))),
                  ],
                ),
              ),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(genres.join(' · '), textAlign: TextAlign.center, style: meta),
              ],
              if (drama.company != null) ...[
                const SizedBox(height: 4),
                Text(l.byStudio(drama.company!.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textDim)),
              ],
              if (drama.synopsis.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _synopsisOpen = !_synopsisOpen),
                  child: AnimatedSize(
                    duration: AppMotion.slow,
                    curve: AppMotion.curve,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        Text(
                          drama.synopsis,
                          textAlign: TextAlign.center,
                          maxLines: _synopsisOpen ? null : 3,
                          overflow: _synopsisOpen ? null : TextOverflow.ellipsis,
                          style: text.bodyMedium!.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(_synopsisOpen ? l.showLess : l.readMore,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PillButton(
                label: l.heroPlay,
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: () => _play(firstEpisode),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MyListButton(drama: drama)),
                  const SizedBox(width: 10),
                  _ShareButton(onTap: () => shareDrama(drama)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _episodesSection(Drama drama) {
    final l = context.l10n;
    final detail = _detail;
    final header = SliverToBoxAdapter(
      child: SectionHeader(
        title: l.episodesTitle,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
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
            title: l.episodesComingSoon,
            compact: true,
          ),
        ),
      ];
    }
    final isVip = context.select<AuthState, bool>((a) => a.isVip);
    final freeInfo = drama.freeEpisodes > 0
        ? l.freeEpisodesInfo(drama.freeEpisodes, drama.coinsPerEpisode)
        : null;
    return [
      header,
      if (freeInfo != null && !isVip)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(freeInfo, style: TextStyle(fontSize: 12.5, color: AppColors.textDim)),
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
      SliverToBoxAdapter(child: SectionHeader(title: context.l10n.youMayAlsoLike)),
      SliverToBoxAdapter(child: PosterShelf(dramas: related, heroScope: 'related-${widget.slug}')),
    ];
  }
}

class _MyListButton extends StatelessWidget {
  const _MyListButton({required this.drama});
  final Drama drama;

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>().contains(drama);
    return SizedBox(
      height: 50,
      child: Material(
        color: AppColors.text.withValues(alpha: 0.1),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => toggleFavorite(context, drama),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.normal,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  fav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  key: ValueKey(fav),
                  size: 20,
                  color: fav ? AppColors.primary : AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(fav ? context.l10n.inMyList : context.l10n.navMyList,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.actionShare,
        child: Material(
          color: AppColors.text.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 50,
              child: Icon(Icons.ios_share_rounded, size: 20, color: AppColors.text),
            ),
          ),
        ),
      );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            SizedBox(height: 20),
            Center(child: SizedBox(width: 148, height: 263, child: SkeletonBox(radius: 18))),
            SizedBox(height: 20),
            Center(child: SkeletonBox(height: 24, width: 220)),
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
