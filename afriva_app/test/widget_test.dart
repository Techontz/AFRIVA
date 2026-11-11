// Basic smoke tests that run fully offline (no API, no font downloads).
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/drama.dart';
import 'package:afriva_app/models/episode.dart';
import 'package:afriva_app/models/user.dart';
import 'package:afriva_app/state/settings_state.dart';
import 'package:afriva_app/widgets/afriva_logo.dart';
import 'package:afriva_app/widgets/badges.dart';
import 'package:afriva_app/widgets/states.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: (() {
        AppTheme.init(useGoogleFonts: false);
        return AppTheme.light;
      })(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('Afriva logo renders the brand image', (tester) async {
    await tester.pumpWidget(_wrap(const AfrivaLogo()));
    expect(find.bySemanticsLabel('Afriva'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/brand/logo.webp');
  });

  testWidgets('State message shows its action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(StateMessage(
      icon: Icons.bookmark_border_rounded,
      title: 'No favorites yet',
      actionLabel: 'Browse dramas',
      onAction: () => tapped = true,
    )));
    expect(find.text('No favorites yet'), findsOneWidget);
    await tester.tap(find.text('Browse dramas'));
    expect(tapped, isTrue);
  });

  testWidgets('Badges render', (tester) async {
    await tester.pumpWidget(_wrap(const Row(
      mainAxisSize: MainAxisSize.min,
      children: [DramaBadge('vip'), DramaBadge('new'), VipPill(), CoinAmount(200)],
    )));
    expect(find.text('New'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('Kiswahili locale renders Kiswahili strings', (tester) async {
    await tester.pumpWidget(_wrap(
      ErrorState(error: Exception('x'), onRetry: () {}),
      locale: const Locale('sw'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hitilafu imetokea'), findsOneWidget);
    expect(find.text('Jaribu tena'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  test('Legacy language names migrate to codes', () async {
    SharedPreferences.setMockInitialValues({'language': 'Kiswahili'});
    final s = SettingsState();
    await s.load();
    expect(s.languageCode, 'sw');
    expect(L10n.code, 'sw');
    expect((await SharedPreferences.getInstance()).getString('language'), 'sw');
    s.setLanguage('en');
    expect(L10n.code, 'en');
  });

  test('Models parse SPEC §6 payloads', () {
    final d = Drama.fromJson({
      'id': 1,
      'slug': 'the-chiefs-daughter',
      'title': "The Chief's Daughter",
      'total_episodes': 60,
      'free_episodes': 5,
      'badge': 'hot',
      'views': '1250000',
      'categories': [
        {'id': 1, 'name': 'Romance', 'slug': 'romance'}
      ],
      'tags': ['Billionaire', 'Secret Identity'],
      'company': {'id': 1, 'name': 'Kilima Studios', 'slug': 'kilima-studios'},
      'is_favorite': false,
    });
    expect(d.views, 1250000);
    expect(d.chips, ['Romance', 'Billionaire']);

    final e = Episode.fromJson({'id': 9, 'number': 6, 'is_free': false, 'is_unlocked': false});
    expect(e.isLocked, isTrue);

    final u = User.fromJson({
      'id': 7,
      'name': 'Baraka Kimaro',
      'coins': 120,
      'is_vip': true,
      'active_subscription': {'id': 1, 'type': 'monthly', 'status': 'active', 'is_active': true},
    });
    expect(u.isVip, isTrue);
    expect(u.initials, 'BK');
  });
}
