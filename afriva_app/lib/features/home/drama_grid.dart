import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

/// Paginated, pull-to-refresh poster grid over `GET /dramas`.
class DramaGrid extends StatefulWidget {
  const DramaGrid({
    super.key,
    this.category,
    this.query,
    this.sort = 'popular',
    required this.heroScope,
    this.padding,
  });

  final String? category;
  final String? query;
  final String sort;
  final String heroScope;
  final EdgeInsets? padding;

  @override
  State<DramaGrid> createState() => _DramaGridState();
}

class _DramaGridState extends State<DramaGrid> with AutomaticKeepAliveClientMixin {
  final _items = <Drama>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant DramaGrid old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category || old.query != widget.query || old.sort != widget.sort) {
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
      }
    });
    final page = reset ? 1 : _page + 1;
    try {
      final res = await context.read<CatalogService>().dramas(
            category: widget.category,
            q: widget.query,
            sort: widget.sort,
            page: page,
          );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(res.items.where((d) => !_items.any((e) => e.id == d.id)));
        _page = res.currentPage;
        _hasMore = res.hasMore;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    if (_items.isEmpty && _loading) return const GridSkeleton();
    if (_items.isEmpty && _error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ScrollableFill(child: ErrorState(error: _error!, onRetry: () => _load(reset: true))),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ScrollableFill(
          child: StateMessage(
            icon: Icons.movie_filter_outlined,
            title: context.tr('No dramas here yet'),
            message: context.tr('New stories land every week. Check back soon.'),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_hasMore && !_loading && n.metrics.extentAfter < 600) _load();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: (widget.padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 0)),
              sliver: SliverGrid.builder(
                gridDelegate: posterGridDelegate,
                itemCount: _items.length,
                itemBuilder: (_, i) => PosterCard(drama: _items[i], heroScope: widget.heroScope),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
                child: Center(
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : _error != null
                          ? TextButton(onPressed: _load, child: Text(context.tr('Tap to load more')))
                          : !_hasMore
                              ? Text(context.tr("You've reached the end"),
                                  style: Theme.of(context).textTheme.labelSmall)
                              : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
