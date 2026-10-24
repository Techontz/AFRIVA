import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import '../profile/watch_history_screen.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthState, bool>((a) => a.isLoggedIn);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My List'),
          bottom: loggedIn
              ? const TabBar(
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [Tab(text: 'Favorites'), Tab(text: 'History')],
                )
              : null,
        ),
        body: loggedIn
            ? const TabBarView(children: [_FavoritesTab(), HistoryList()])
            : StateMessage(
                icon: Icons.bookmark_border_rounded,
                title: 'Your list lives here',
                message: 'Log in to save dramas and keep track of what you watch across devices.',
                actionLabel: 'Log in',
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
                title: 'No favorites yet',
                message: 'Tap "My List" on any drama to save it here.',
                actionLabel: 'Browse dramas',
                onAction: () => context.go('/home'),
              ),
            )
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
              gridDelegate: posterGridDelegate,
              itemCount: items.length,
              itemBuilder: (_, i) => PosterCard(drama: items[i], heroScope: 'mylist'),
            ),
    );
  }
}
