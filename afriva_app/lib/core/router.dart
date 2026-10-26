import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/login_screen.dart';
import '../features/creator/creator_apply_screen.dart';
import '../features/creator/creator_agreement_screen.dart';
import '../features/creator/creator_home_screen.dart';
import '../features/creator/series_detail_screen.dart';
import '../features/creator/series_form_screen.dart';
import '../features/profile/coin_history_screen.dart';
import '../features/profile/help_screen.dart';
import '../features/profile/receipt_screen.dart';
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
            // Scope §03 navigation: Nyumbani · Tafuta · Vipendwa · Profile.
            StatefulShellBranch(routes: [
              GoRoute(path: '/search', builder: (_, _) => const SearchScreen(embedded: true)),
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
          path: '/foryou',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, s) => _fadePage(s, Theme(data: AppTheme.video, child: const ForYouScreen())),
        ),
        GoRoute(
          path: '/coins',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const CoinHistoryScreen(),
        ),
        GoRoute(
          path: '/receipt/:reference',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => ReceiptScreen(reference: s.pathParameters['reference']!),
        ),
        GoRoute(
          path: '/help',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const HelpScreen(),
        ),
        // Creator Studio ("Wasilisha Kazi Yako").
        GoRoute(
          path: '/creator',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const CreatorHomeScreen(),
        ),
        GoRoute(
          path: '/creator/apply',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const CreatorApplyScreen(),
        ),
        GoRoute(
          path: '/creator/agreement',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const CreatorAgreementScreen(),
        ),
        GoRoute(
          path: '/creator/series/new',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const SeriesFormScreen(),
        ),
        GoRoute(
          path: '/creator/series/:id',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => SeriesDetailScreen(id: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/creator/series/:id/edit',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, s) => SeriesFormScreen(id: int.tryParse(s.pathParameters['id'] ?? '')),
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
