import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/home.dart';
import '../../services/catalog_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/net_image.dart';
import '../../widgets/afriva_logo.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'featured_block.dart';
import 'drama_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category> _categories = const [];
  // Keeps the Home tab's state when the tab count changes after categories load.
  final _popularKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await context.read<CatalogService>().categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // Tabs gracefully fall back to Popular / New only.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[
      context.tr('Home'),
      context.tr('Popular'),
      context.tr('New'),
      ..._categories.map((c) => c.name),
    ];
    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        body: Column(
          children: [
            _HomeHeader(tabs: tabs),
            Expanded(
              child: TabBarView(
                children: [
                  _PopularTab(key: _popularKey, categories: _categories),
                  const DramaGrid(sort: 'popular', heroScope: 'tab-popular'),
                  const DramaGrid(sort: 'newest', heroScope: 'tab-new'),
                  for (final c in _categories)
                    DramaGrid(category: c.slug, heroScope: 'tab-${c.slug}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.tabs});
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        // Dark top bar: logo, pill search, support.
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: afrivaOverlayStyle,
          child: Container(
            color: AppColors.topBar,
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  const AfrivaLogo(size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        context.go('/search');
                      },
                      child: Hero(
                        tag: 'search-field-home',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.topBarField,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.tr('Search'),
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodyMedium!
                                        .copyWith(color: AppColors.topBarHint, fontSize: 13.5),
                                  ),
                                ),
                                const Icon(Icons.search_rounded, size: 20, color: AppColors.topBarHint),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: context.tr('Help & support'),
                    child: Material(
                      color: AppColors.topBarField,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Haptics.tap();
                          context.push('/settings');
                        },
                        child: const SizedBox.square(
                          dimension: 36,
                          child: Icon(Icons.headset_mic_outlined, size: 19, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Category tabs on the white body.
        Container(
          color: AppColors.bg,
          child: TabBar(
            isScrollable: true,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.primary, width: 2.5),
            ),
            onTap: (_) => Haptics.tap(),
            tabs: [for (final t in tabs) Tab(height: 42, text: t)],
          ),
        ),
      ],
    );
  }
}

class _PopularTab extends StatefulWidget {
  const _PopularTab({super.key, required this.categories});
  final List<Category> categories;

  @override
  State<_PopularTab> createState() => _PopularTabState();
}

class _PopularTabState extends State<_PopularTab> with AutomaticKeepAliveClientMixin {
  HomeData? _data;
  Object? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<CatalogService>().home();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _more(HomeSection s) {
    Haptics.tap();
    if (s.layout == 'ranking') {
      context.push('/rankings');
      return;
    }
    final key = s.key.toLowerCase().replaceAll('_', '-');
    final cat = widget.categories.where((c) => c.slug == s.category || c.slug == key || key.contains(c.slug)).firstOrNull;
    final sort = key.contains('new') ? 'newest' : 'popular';
    final params = <String, String>{
      'title': s.title,
      'sort': sort,
      'category': ?cat?.slug,
    };
    context.push(Uri(path: '/browse', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    if (data == null && _loading) return const HomeSkeleton();
    if (data == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ScrollableFill(child: ErrorState(error: _error ?? 'error', onRetry: _load)),
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bg,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _Greeting()),
          if (data.banners.isNotEmpty)
            SliverToBoxAdapter(child: FeaturedBlock(dramas: data.banners)),
          const SliverToBoxAdapter(child: _ForYouEntry()),
          if (data.banners.isEmpty && data.sections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: StateMessage(
                icon: Icons.movie_filter_outlined,
                title: context.tr('Nothing to watch yet'),
                message: context.tr('Our studios are busy filming. Pull down to refresh.'),
              ),
            ),
          // The API already orders sections per scope §02: Endelea kutazama, Zinazovuma, Mpya, categories.
          for (final s in data.sections) ..._section(s),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }

  String _title(HomeSection s) =>
      s.key.toLowerCase().startsWith('must') ? context.tr('Must-sees') : s.title;

  /// Every section renders as a 3-column poster grid (two rows).
  List<Widget> _section(HomeSection s) {
    if (s.dramas.isEmpty) return const [];
    if (s.isContinue) {
      return [
        SliverToBoxAdapter(child: SectionHeader(title: context.tr('Continue watching'))),
        SliverToBoxAdapter(child: _ContinueRow(dramas: s.dramas)),
      ];
    }
    return [
      SliverToBoxAdapter(child: SectionHeader(title: _title(s), onMore: () => _more(s))),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: posterGridDelegate,
          itemCount: s.dramas.length.clamp(0, 6),
          itemBuilder: (_, i) => PosterCard(drama: s.dramas[i], heroScope: 'home-${s.key}'),
        ),
      ),
    ];
  }
}

/// "Habari! Uangalie nini leo?" under the top bar (scope §03).
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = context.select<AuthState, String?>((a) => a.user?.name.split(' ').first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        name == null || name.isEmpty
            ? context.tr('Hello! What would you like to watch today?')
            : context.tr('Hello {name}! What would you like to watch today?', {'name': name}),
        style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Entry to the full-screen For You feed (it is no longer a tab).
class _ForYouEntry extends StatelessWidget {
  const _ForYouEntry();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.topBar,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () {
            Haptics.tap();
            context.push('/foryou');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('For You'), style: text.titleSmall!.copyWith(color: Colors.white)),
                      Text(
                        context.tr('Swipe through the first episode of every series'),
                        style: text.bodySmall!.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Endelea kutazama": unfinished series with a progress bar; tapping resumes in the player.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.dramas});
  final List<Drama> dramas;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dramas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = dramas[i];
          final resume = d.resume;
          final ep = resume?.episodeNumber ?? 1;
          return GestureDetector(
            onTap: () {
              Haptics.tap();
              context.push('/watch/${d.slug}/$ep');
            },
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.poster),
                    child: Stack(
                      children: [
                        SizedBox(width: 112, height: 150, child: NetImage(d.posterUrl, memCacheWidth: 240)),
                        const Positioned.fill(
                          child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: resume?.progress ?? 0,
                            minHeight: 3,
                            color: AppColors.primary,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                  Text(context.tr('EP {n}', {'n': ep}), style: text.labelSmall!.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
