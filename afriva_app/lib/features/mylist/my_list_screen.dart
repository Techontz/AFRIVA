import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/calm.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import '../profile/watch_history_screen.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthState, bool>((a) => a.isLoggedIn);
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navMyList),
          bottom: loggedIn
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(46),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 34,
                        child: CalmTabBar(labels: [l.myListFavorites, l.myListHistory]),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: loggedIn
            ? const TabBarView(children: [_FavoritesTab(), HistoryList()])
            : StateMessage(
                icon: Icons.bookmark_border_rounded,
                title: l.myListSignedOutTitle,
                message: l.myListSignedOutMessage,
                actionLabel: l.actionLogIn,
                onAction: () => context.push('/login'),
              ),
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab();

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> with AutomaticKeepAliveClientMixin {
  Object? _error;
  bool _loading = false;

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
      await context.read<FavoritesState>().load();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final favs = context.watch<FavoritesState>();
    final items = favs.items;
    if (!favs.loaded && _loading) return const GridSkeleton();
    if (!favs.loaded && _error != null) return ErrorState(error: _error!, onRetry: _load);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: items.isEmpty
          ? ScrollableFill(
              child: StateMessage(
                icon: Icons.bookmark_add_outlined,
                title: context.l10n.favoritesEmptyTitle,
                message: context.l10n.favoritesEmptyMessage,
                actionLabel: context.l10n.browseDramas,
                onAction: () => context.go('/home'),
              ),
            )
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
              gridDelegate: posterGrid(context),
              itemCount: items.length,
              itemBuilder: (_, i) => PosterCard(drama: items[i], heroScope: 'mylist'),
            ),
    );
  }
}
