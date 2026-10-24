import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

class RankingsScreen extends StatelessWidget {
  const RankingsScreen({super.key, this.initialType = 'trending'});
  final String initialType;

  static const _types = [('trending', 'Trending'), ('new', 'New'), ('popular', 'Most Popular')];

  @override
  Widget build(BuildContext context) {
    final initial = _types.indexWhere((t) => t.$1 == initialType).clamp(0, _types.length - 1);
    return DefaultTabController(
      length: _types.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rankings'),
          bottom: TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [for (final t in _types) Tab(text: t.$2)],
          ),
        ),
        body: TabBarView(
          children: [for (final t in _types) _RankingList(type: t.$1)],
        ),
      ),
    );
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({required this.type});
  final String type;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> with AutomaticKeepAliveClientMixin {
  late Future<List<Drama>> _future = _fetch();

  @override
  bool get wantKeepAlive => true;

  Future<List<Drama>> _fetch() => context.read<CatalogService>().rankings(type: widget.type);

  Future<void> _refresh() async {
    final f = _fetch();
    setState(() => _future = f);
    await f.catchError((_) => <Drama>[]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Drama>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const ListSkeleton(thumbWidth: 72);
        if (snap.hasError) {
          return ErrorState(error: snap.error!, onRetry: _refresh);
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const StateMessage(icon: Icons.leaderboard_outlined, title: 'No rankings yet');
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                RankingTile(rank: i + 1, drama: items[i], heroScope: 'rank-${widget.type}'),
          ),
        );
      },
    );
  }
}
