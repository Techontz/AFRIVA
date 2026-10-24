import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/home.dart';
import '../../services/me_service.dart';
import '../../widgets/net_image.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

class WatchHistoryScreen extends StatelessWidget {
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Watch history')),
        body: const HistoryList(),
      );
}

/// Reusable history list (also used in the My List "History" tab).
class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> with AutomaticKeepAliveClientMixin {
  List<HistoryEntry>? _items;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<MeService>().history();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _items;
    if (items == null) {
      return _error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton();
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: items.isEmpty
          ? ScrollableFill(
              child: StateMessage(
                icon: Icons.history_rounded,
                title: 'Nothing watched yet',
                message: 'Episodes you watch will show up here so you can pick up where you left off.',
                actionLabel: 'Discover dramas',
                onAction: () => context.go('/home'),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _HistoryTile(entry: items[i]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = entry.drama;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Haptics.tap();
        context.push('/watch/${d.slug}/${entry.episodeNumber}');
      },
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(d.backdropOrPoster, memCacheWidth: 360),
                    const DecoratedBox(decoration: BoxDecoration(color: Color(0x33000000))),
                    const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30)),
                    if (entry.progress > 0)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'EP ${entry.episodeNumber}${d.totalEpisodes > 0 ? ' / ${d.totalEpisodes}' : ''}',
                  style: text.labelMedium!.copyWith(color: AppColors.primary),
                ),
                if (entry.updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(Fmt.relative(entry.updatedAt), style: text.labelSmall),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        ],
      ),
    );
  }
}
