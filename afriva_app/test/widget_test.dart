// Basic smoke tests that run fully offline (no API, no font downloads).
import 'package:afriva_app/core/i18n.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/models/drama.dart';
import 'package:afriva_app/models/commerce.dart';
import 'package:afriva_app/models/episode.dart';
import 'package:afriva_app/models/studio.dart';
import 'package:afriva_app/models/user.dart';
import 'package:afriva_app/widgets/afriva_logo.dart';
import 'package:afriva_app/widgets/badges.dart';
import 'package:afriva_app/widgets/states.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: (() {
        AppTheme.init(useGoogleFonts: false);
        return AppTheme.light;
      })(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('Afriva logo renders the wordmark', (tester) async {
    await tester.pumpWidget(_wrap(const AfrivaLogo()));
    expect(find.text('Afriva'), findsOneWidget);
    expect(find.byType(AfrivaMark), findsOneWidget);
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
    // The interface is Kiswahili by default (scope §01).
    expect(find.text('Mpya'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
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

  test('Kiswahili is the default language', () {
    expect(I18n.language, 'Kiswahili');
    expect(trNow('Continue watching'), 'Endelea kutazama');
  });

  test('Models parse project-scope payloads (SPEC §8)', () {
    final e = Episode.fromJson({'id': 9, 'number': 9, 'is_free': false, 'is_unlocked': false, 'access': 'locked', 'price_coins': 30});
    expect(e.isLocked, isTrue);
    expect(e.priceCoins, 30);

    final play = PlayResult.fromJson({
      'video_url': 'https://x/master.m3u8',
      'sources': [
        {'quality': 'auto', 'label': 'Auto', 'url': 'https://x/master.m3u8', 'type': 'hls'},
        {'quality': '720p', 'label': '720p', 'url': 'https://x/720p/index.m3u8', 'type': 'hls'},
      ],
      'resume_seconds': 42,
      'session_id': 'abc-123',
      'episode': {'id': 1, 'number': 1, 'access': 'free', 'is_free': true},
    });
    expect(play.playable.length, 2);
    expect(play.resumeSeconds, 42);

    final d = Drama.fromJson({'id': 1, 'slug': 's', 'title': 'T', 'resume': {'episode_number': 3, 'progress_seconds': 30, 'duration_seconds': 60}});
    expect(d.resume!.episodeNumber, 3);
    expect(d.resume!.progress, 0.5);

    final m = PaymentMethod.fromJson({'id': 1, 'code': 'visa', 'name': 'Visa', 'type': 'card', 'is_available': false});
    expect(m.isAvailable, isFalse);

    final s = StudioDrama.fromJson({
      'id': 5, 'slug': 'x', 'title': 'X', 'review_status': 'changes_requested',
      'episodes': [{'id': 1, 'number': 1, 'review_status': 'changes_requested'}],
      'reviews': [{'id': 1, 'action': 'request_changes', 'notes': 'Sauti'}],
    });
    expect(s.editable, isTrue);
    expect(s.canSubmit, isTrue);
    expect(s.reviews.first.notes, 'Sauti');
  });
}
