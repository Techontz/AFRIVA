import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/home.dart';
import '../../services/catalog_service.dart';
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
    final tabs = <String>['Home', 'Popular', 'New', ..._categories.map((c) => c.name)];
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
                  const AfrivaLogo(size: 20, color: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        context.push('/search');
                      },
                      child: Hero(
                        tag: 'search-field',
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
                                    'Search',
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
                    message: 'Help & support',
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
    final cat = widget.categories.where((c) => c.slug == key || key.contains(c.slug)).firstOrNull;
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
          if (data.banners.isNotEmpty)
            SliverToBoxAdapter(child: FeaturedBlock(dramas: data.banners)),
          if (data.banners.isEmpty && data.sections.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: StateMessage(
                icon: Icons.movie_filter_outlined,
                title: 'Nothing to watch yet',
                message: 'Our studios are busy filming. Pull down to refresh.',
              ),
            ),
          for (final s in _ordered(data.sections)) ..._section(s),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }

  /// Featured banner first, then Must-sees, Trending, Hidden Gems, then
  /// category sections, then anything else the API sends.
  List<HomeSection> _ordered(List<HomeSection> sections) {
    String norm(String k) => k.toLowerCase().replaceAll('_', '-');
    const lead = ['must-watch', 'must-sees', 'must-see', 'trending', 'hidden-gems'];
    final catSlugs = widget.categories.map((c) => c.slug).toSet();
    final catKeys = {...catSlugs, 'romance', 'revenge', 'billionaire', 'family', 'village-life'};
    int rank(HomeSection s) {
      final k = norm(s.key);
      final i = lead.indexOf(k);
      if (i >= 0) return i;
      if (catKeys.contains(k)) return 10;
      return 20;
    }

    final indexed = sections.indexed.toList()
      ..sort((a, b) {
        final r = rank(a.$2).compareTo(rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  static String _title(HomeSection s) =>
      s.key.toLowerCase().startsWith('must') ? 'Must-sees' : s.title;

  /// Every section renders as a 3-column poster grid (two rows).
  List<Widget> _section(HomeSection s) {
    if (s.dramas.isEmpty) return const [];
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
