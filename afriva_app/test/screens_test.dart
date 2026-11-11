// Pumps key screens with fake catalog data shaped like the real API.
import 'dart:async';

import 'package:afriva_app/core/api_client.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/home/featured_block.dart';
import 'package:afriva_app/features/home/browse_screen.dart';
import 'package:afriva_app/features/home/home_screen.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/drama.dart';
import 'package:afriva_app/models/home.dart';
import 'package:afriva_app/services/catalog_service.dart';
import 'package:afriva_app/widgets/skeletons.dart';
import 'package:afriva_app/widgets/states.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _drama(int id, {String? badge, String category = 'historical'}) => {
      'id': id,
      'slug': 'drama-$id',
      'title': 'Drama $id: Siri ya Tajiri',
      'poster_url': '',
      'backdrop_url': '',
      'total_episodes': 30 + id,
      'free_episodes': 5,
      'coins_per_episode': 30,
      'badge': badge,
      'views': 1000 * id,
      'categories': [
        {'id': 1, 'name': 'Historical', 'slug': category}
      ],
    };

final _home = HomeData.fromJson({
  'banners': [
    {..._drama(1, badge: 'hot'), 'backdrop_url': 'https://cdn.test/wide-1.jpg'},
    {..._drama(2), 'backdrop_url': 'https://cdn.test/wide-2.jpg'},
  ],
  'sections': [
    {
      'key': 'must_watch',
      'title': 'Must-Watch',
      'layout': 'row',
      'dramas': [_drama(1, badge: 'hot'), _drama(2, badge: 'new'), _drama(3, badge: 'vip')],
    },
    {
      'key': 'trending',
      'title': 'Trending Now',
      'layout': 'ranking',
      'dramas': [for (var i = 4; i < 8; i++) _drama(i)],
    },
    {
      'key': 'zombie_stories',
      'title': 'Zombie Stories',
      'layout': 'row',
      'category': 'zombie',
      'dramas': [_drama(8, category: 'zombie'), _drama(9, category: 'zombie')],
    },
  ],
});

class _FakeCatalog extends CatalogService {
  _FakeCatalog({this.homeFuture}) : super(ApiClient());

  final Future<HomeData>? homeFuture;
  final dramaQueries = <String?>[];

  @override
  Future<HomeData> home() => homeFuture ?? Future.value(_home);

  @override
  Future<List<Category>> categories() async => const [
        Category(id: 1, name: 'Historical', slug: 'historical', dramasCount: 6),
        Category(id: 2, name: 'Zombie', slug: 'zombie', dramasCount: 2),
        Category(id: 3, name: 'Romance', slug: 'romance', dramasCount: 0),
      ];

  @override
  Future<Paginated<Drama>> dramas({
    String? category,
    String? q,
    String sort = 'popular',
    int page = 1,
    int perPage = 18,
  }) async {
    dramaQueries.add(category);
    return Paginated(items: [Drama.fromJson(_drama(20, category: category ?? 'all'))]);
  }

  @override
  Future<List<Drama>> rankings({String type = 'trending'}) async =>
      [for (var i = 4; i < 8; i++) Drama.fromJson(_drama(i))];
}

Widget _app(CatalogService catalog, {required String initial}) {
  AppTheme.init(useGoogleFonts: false);
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/browse',
      builder: (_, s) => BrowseScreen(
        title: s.uri.queryParameters['title'],
        category: s.uri.queryParameters['category'],
      ),
    ),
    GoRoute(path: '/drama/:slug', builder: (_, s) => Text('detail ${s.pathParameters['slug']}')),
  ]);
  return Provider<CatalogService>.value(
    value: catalog,
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: router,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The vertical page scroller (shelves inside it scroll horizontally).
final _pageScroll = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
).first;

void main() {
  testWidgets('Home shows a shimmer skeleton while loading', (tester) async {
    _phone(tester);
    final pending = Completer<HomeData>();
    await tester.pumpWidget(_app(_FakeCatalog(homeFuture: pending.future), initial: '/home'));
    await tester.pump();
    expect(find.byType(HomeSkeleton), findsOneWidget);
    pending.complete(_home);
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeSkeleton), findsNothing);
  });

  testWidgets('Home renders the featured block and any API section key', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeCatalog(), initial: '/home'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FeaturedBlock), findsOneWidget);
    // Section titles come from the API, including keys the app never heard of.
    expect(find.byType(SectionHeader), findsWidgets);
    final zombie = find.text('Zombie Stories');
    await tester.scrollUntilVisible(zombie, 300, scrollable: _pageScroll);
    expect(zombie, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all on a genre section opens a category-filtered browse list', (tester) async {
    _phone(tester);
    final catalog = _FakeCatalog();
    await tester.pumpWidget(_app(catalog, initial: '/home'));
    await tester.pump();
    await tester.pump();
    final header = find.ancestor(of: find.text('Zombie Stories'), matching: find.byType(SectionHeader));
    await tester.scrollUntilVisible(header, 300, scrollable: _pageScroll);
    final more = find.descendant(of: header, matching: find.text('See all'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.byType(BrowseScreen), findsOneWidget);
    expect(find.text('Zombie Stories'), findsOneWidget);
    expect(catalog.dramaQueries.last, 'zombie');
  });
}
