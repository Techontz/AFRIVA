import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../models/home.dart';
import '../../services/catalog_service.dart';
import '../../widgets/afriva_logo.dart';
import '../../widgets/calm.dart';
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
  final _scrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _categories = context.read<CatalogService>().cachedCategories() ?? _categories;
    _loadCategories();
  }

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
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
    final l = context.l10n;
    final tabs = <String>[l.navHome, l.sortPopular, l.rankNew, ..._categories.map((c) => c.name)];
    final inset = MediaQuery.paddingOf(context).top + _HomeHeader.height;
    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: afrivaLightOverlayStyle,
        child: Scaffold(
          body: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.axis == Axis.vertical) _scrolled.value = n.metrics.pixels > 8;
                  return false;
                },
                child: TabBarView(
                  children: [
                    _PopularTab(key: _popularKey, categories: _categories, topInset: inset),
                    DramaGrid(sort: 'popular', heroScope: 'tab-popular', topInset: inset),
                    DramaGrid(sort: 'newest', heroScope: 'tab-new', topInset: inset),
                    for (final c in _categories)
                      DramaGrid(category: c.slug, heroScope: 'tab-${c.slug}', topInset: inset),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HomeHeader(tabs: tabs, scrolled: _scrolled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header that blends into the page: see-through over the hero, solid once
/// the page scrolls under it.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.tabs, required this.scrolled});
  final List<String> tabs;
  final ValueListenable<bool> scrolled;

  /// Bar plus chips, excluding the status bar.
  static const height = 98.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<bool>(
      valueListenable: scrolled,
      builder: (context, solid, child) => AnimatedContainer(
        duration: AppMotion.normal,
        color: AppColors.bg.withValues(alpha: solid ? 1 : 0),
        padding: EdgeInsets.only(top: top),
        child: child,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 6),
                child: Row(
                  children: [
                    const AfrivaLogo(size: 20),
                    const Spacer(),
                    IconButton(
                      tooltip: l.searchHint,
                      icon: Icon(Icons.search_rounded, color: AppColors.text),
                      onPressed: () {
                        Haptics.tap();
                        context.push('/search');
                      },
                    ),
                    IconButton(
                      tooltip: l.helpSupport,
                      icon: Icon(Icons.headset_mic_outlined, size: 21, color: AppColors.text),
                      onPressed: () {
                        Haptics.tap();
                        context.push('/settings');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 34, child: CalmTabBar(labels: tabs)),
          ],
        ),
      ),
    );
  }
}

class _PopularTab extends StatefulWidget {
  const _PopularTab({super.key, required this.categories, this.topInset = 0});
  final List<Category> categories;
  final double topInset;

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
    // Paint the last saved home instantly, then refresh it from the API.
    _data = context.read<CatalogService>().cachedHome();
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
    // Genre sections carry their category slug; older payloads only a key.
    final cat = s.category ??
        widget.categories.where((c) => c.slug == key || key.contains(c.slug)).firstOrNull?.slug;
    final sort = key.contains('new') ? 'newest' : 'popular';
    final params = <String, String>{
      'title': s.title,
      'sort': sort,
      'category': ?cat,
    };
    context.push(Uri(path: '/browse', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    if (data == null && _loading) return HomeSkeleton(topInset: widget.topInset);
    if (data == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ScrollableFill(child: ErrorState(error: _error ?? 'error', onRetry: _load)),
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      edgeOffset: widget.topInset,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (data.banners.isNotEmpty)
            SliverToBoxAdapter(child: FeaturedBlock(dramas: data.banners, topInset: widget.topInset)),
          if (data.banners.isEmpty && data.sections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: StateMessage(
                icon: Icons.movie_filter_outlined,
                title: context.l10n.homeEmptyTitle,
                message: context.l10n.homeEmptyMessage,
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
      if (s.category != null || catKeys.contains(k)) return 10;
      return 20;
    }

    final indexed = sections.indexed.toList()
      ..sort((a, b) {
        final r = rank(a.$2).compareTo(rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  String _title(HomeSection s) =>
      s.key.toLowerCase().startsWith('must') ? context.l10n.homeMustSees : s.title;

  /// Every section renders as a horizontal shelf with a quiet "See all".
  List<Widget> _section(HomeSection s) {
    if (s.dramas.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: SectionHeader(title: _title(s), onMore: () => _more(s))),
      SliverToBoxAdapter(child: PosterShelf(dramas: s.dramas, heroScope: 'home-${s.key}')),
    ];
  }
}
