import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../widgets/calm.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

class RankingsScreen extends StatelessWidget {
  const RankingsScreen({super.key, this.initialType = 'trending'});
  final String initialType;

  static const _types = ['trending', 'new', 'popular'];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {'trending': l.rankTrending, 'new': l.rankTabNewHot, 'popular': l.rankTabAllTime};
    final initial = _types.indexOf(initialType).clamp(0, _types.length - 1);
    return DefaultTabController(
      length: _types.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.rankingsTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l.rankingsSubtitle, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 12),
                SizedBox(height: 34, child: CalmTabBar(labels: [for (final t in _types) labels[t]!])),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [for (final t in _types) _RankingList(type: t)],
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
          return StateMessage(icon: Icons.leaderboard_outlined, title: context.l10n.rankingsEmpty);
        }
        final top = items.take(3).toList();
        final rest = items.skip(3).toList();
        final l = context.l10n;
        final blurb = switch (widget.type) {
          'new' => l.rankBlurbNew,
          'popular' => l.rankBlurbPopular,
          _ => l.rankBlurbTrending,
        };
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
            itemCount: rest.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(blurb, style: TextStyle(fontSize: 13.5, color: AppColors.textDim)),
                    const SizedBox(height: 26),
                    _Podium(dramas: top, heroScope: 'podium-${widget.type}'),
                    const SizedBox(height: 26),
                  ],
                );
              }
              return RankingTile(rank: i + 3, drama: rest[i - 1], heroScope: 'rank-${widget.type}');
            },
          ),
        );
      },
    );
  }
}

/// Medal gradients for #1, #2 and #3.
const _medals = [
  [Color(0xFFFFE08A), Color(0xFFC9971C)],
  [Color(0xFFF1F4F7), Color(0xFF8D99A6)],
  [Color(0xFFF3B37A), Color(0xFF9A5422)],
];

/// Top 3 as a podium: full posters, #1 centre and raised, medal under each.
class _Podium extends StatelessWidget {
  const _Podium({required this.dramas, required this.heroScope});
  final List<Drama> dramas;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final order = dramas.length == 3 ? const [1, 0, 2] : [for (var i = 0; i < dramas.length; i++) i];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (slot, i) in order.indexed) ...[
          if (slot > 0) const SizedBox(width: 10),
          Expanded(child: _PodiumItem(drama: dramas[i], rank: i + 1, heroScope: heroScope)),
        ],
        if (dramas.length < 3)
          for (var i = dramas.length; i < 3; i++) const Spacer(),
      ],
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({required this.drama, required this.rank, required this.heroScope});
  final Drama drama;
  final int rank;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    final tag = posterHeroTag(drama, heroScope);
    final scaler = MediaQuery.textScalerOf(context);
    final medal = first ? 36.0 : 32.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openDrama(context, drama, heroTag: tag),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FractionallySizedBox(
                widthFactor: first ? 1 : 0.88,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(AppRadii.poster)),
                    boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12))],
                  ),
                  child: Poster(drama: drama, heroTag: tag, cacheWidth: 480),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: medal,
                height: medal,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _medals[rank - 1],
                  ),
                ),
                child: Text(
                  '$rank',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: first ? 16 : 14),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: scaler.scale(13) * 1.3 * 2 + 1,
                child: Text(
                  drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.viewsCount(Fmt.compact(drama.views)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
        const SizedBox(height: 12),
        _QuietPlay(onTap: () => context.push('/watch/${drama.slug}/1', extra: drama)),
      ],
    );
  }
}

class _QuietPlay extends StatelessWidget {
  const _QuietPlay({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.text.withValues(alpha: 0.1),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 15, color: AppColors.text),
                const SizedBox(width: 3),
                Text(
                  context.l10n.heroPlay,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ],
            ),
          ),
        ),
      );
}
