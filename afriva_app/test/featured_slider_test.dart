// Home featured slider: active slide copy, buttons, swipe, autoplay, Play.
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/home/featured_block.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/drama.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

Drama _drama(int id, {String? badge}) => Drama(
      id: id,
      slug: 'drama-$id',
      title: 'Slide Title $id',
      totalEpisodes: 40 + id,
      badge: badge,
      categories: const [
        Category(id: 1, name: 'Romance', slug: 'romance'),
        Category(id: 2, name: 'Revenge', slug: 'revenge'),
        Category(id: 3, name: 'Family', slug: 'family'),
        Category(id: 4, name: 'Extra', slug: 'extra'),
      ],
    );

final _dramas = [_drama(1, badge: 'hot'), _drama(2, badge: 'new'), _drama(3)];

Widget _app({bool reduceMotion = false}) {
  AppTheme.init(useGoogleFonts: false);
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => Scaffold(
        body: CustomScrollView(slivers: [SliverToBoxAdapter(child: FeaturedBlock(dramas: _dramas))]),
      ),
    ),
    GoRoute(
      path: '/watch/:slug/:ep',
      builder: (_, s) => Text('watch ${s.pathParameters['slug']} ep ${s.pathParameters['ep']}'),
    ),
    GoRoute(path: '/drama/:slug', builder: (_, s) => Text('detail ${s.pathParameters['slug']}')),
  ]);
  return MediaQuery(
    data: MediaQueryData(size: const Size(393, 852), disableAnimations: reduceMotion),
    child: MaterialApp.router(
      theme: AppTheme.dark,
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

/// The title of the slide that currently takes taps (inactive slides ignore pointers).
bool _isActive(WidgetTester tester, String title) =>
    find.text(title).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets('renders the active slide copy, meta and both buttons', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Slide Title 1'), findsOneWidget);
    expect(find.text('Slide Title 2'), findsNothing);
    expect(find.text('HOT'), findsOneWidget);
    expect(find.text('41 Episodes'), findsOneWidget);
    // Up to three genres.
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Extra'), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('More info'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping left and right changes the slide', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.drag(find.byType(FeaturedBlock), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_isActive(tester, 'Slide Title 2'), isTrue);
    expect(_isActive(tester, 'Slide Title 1'), isFalse);
    expect(find.text('NEW'), findsWidgets);

    await tester.drag(find.byType(FeaturedBlock), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_isActive(tester, 'Slide Title 1'), isTrue);

    // Wraps around from the first slide to the last.
    await tester.drag(find.byType(FeaturedBlock), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_isActive(tester, 'Slide Title 3'), isTrue);
  });

  testWidgets('auto-advances after the interval', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(heroInterval);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_isActive(tester, 'Slide Title 2'), isTrue);
  });

  testWidgets('reduced motion disables auto-advance', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pump();
    await tester.pump(heroInterval * 2);
    expect(_isActive(tester, 'Slide Title 1'), isTrue);
    expect(find.text('Slide Title 2'), findsNothing);
  });

  testWidgets('Play opens episode 1 of the drama', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('watch drama-1 ep 1'), findsOneWidget);
  });

  testWidgets('More info opens the drama detail', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('More info'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('detail drama-1'), findsOneWidget);
  });
}
