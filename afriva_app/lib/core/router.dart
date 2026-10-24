import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/drama/drama_detail_screen.dart';
import '../features/foryou/for_you_screen.dart';
import '../features/home/browse_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/rankings_screen.dart';
import '../features/mylist/my_list_screen.dart';
import '../features/player/player_screen.dart';
import '../features/profile/payment_history_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/profile/watch_history_screen.dart';
import '../features/search/search_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../widgets/poster_card.dart';
import 'theme.dart';
import '../features/vip/vip_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Fade+slide page used for full-screen routes.
CustomTransitionPage<T> _fadePage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

GoRouter buildRouter({String initialLocation = '/splash'}) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/foryou', builder: (_, _) => Theme(data: AppTheme.video, child: const ForYouScreen())),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/mylist', builder: (_, _) => const MyListScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            ]),
          ],
        ),
        GoRoute(
          path: '/search',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, s) => _fadePage(s, const SearchScreen()),
        ),
        GoRoute(
          path: '/browse',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => BrowseScreen(
            title: s.uri.queryParameters['title'] ?? 'Browse',
            category: s.uri.queryParameters['category'],
            sort: s.uri.queryParameters['sort'] ?? 'popular',
          ),
        ),
        GoRoute(
          path: '/rankings',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => RankingsScreen(initialType: s.uri.queryParameters['type'] ?? 'trending'),
        ),
        GoRoute(
          path: '/drama/:slug',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) {
            final args = s.extra is DramaRouteArgs ? s.extra as DramaRouteArgs : null;
            return DramaDetailScreen(
              slug: s.pathParameters['slug']!,
              initial: args?.drama,
              heroTag: args?.heroTag,
            );
          },
        ),
        GoRoute(
          path: '/watch/:slug/:ep',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, s) => _fadePage(
            s,
            Theme(
              data: AppTheme.video,
              child: PlayerScreen(
                slug: s.pathParameters['slug']!,
                episodeNumber: int.tryParse(s.pathParameters['ep'] ?? '') ?? 1,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/vip',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => VipScreen(initialSection: s.uri.queryParameters['section']),
        ),
        GoRoute(
          path: '/login',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, s) => _fadePage(s, const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, s) => _fadePage(s, const RegisterScreen()),
        ),
        GoRoute(
          path: '/history',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const WatchHistoryScreen(),
        ),
        GoRoute(
          path: '/payments',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const PaymentHistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    );
