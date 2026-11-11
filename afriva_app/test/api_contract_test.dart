// Offline checks that the API client + models handle the payloads the Laravel
// backend actually emits (see backend/app/Http/Resources and controllers).
import 'dart:convert';
import 'dart:typed_data';

import 'package:afriva_app/core/api_client.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/home.dart';
import 'package:afriva_app/services/commerce_service.dart';
import 'package:afriva_app/services/me_service.dart';
import 'package:afriva_app/services/player_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned status + JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<String, (int, Object?)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async {
    requests.add(options);
    final (status, body) = routes[options.path] ?? (404, {'message': 'Not found', 'code': 'not_found'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_FakeAdapter adapter) =>
    ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);

void main() {
  test('402 episode_locked surfaces the unlock info', () async {
    final api = _client(_FakeAdapter({
      '/episodes/12/play': (402, {
        'message': 'This episode is locked.',
        'code': 'episode_locked',
        'unlock': {
          'episode_id': 12,
          'coins_required': 30,
          'user_coins': 45,
          'can_use_pack': true,
          'episodes_remaining': 3,
          'requires_login': false,
        },
      }),
    }));
    await expectLater(
      PlayerService(api).play(12),
      throwsA(isA<EpisodeLockedException>()
          .having((e) => e.info.coinsRequired, 'coinsRequired', 30)
          .having((e) => e.info.userCoins, 'userCoins', 45)
          .having((e) => e.info.canUsePack, 'canUsePack', isTrue)
          .having((e) => e.info.hasEnoughCoins, 'hasEnoughCoins', isTrue)),
    );
  });

  test('play success parses video url and siblings', () async {
    final api = _client(_FakeAdapter({
      '/episodes/5/play': (200, {
        'data': {
          'video_url': '/storage/videos/ep1.mp4',
          'episode': {'id': 5, 'drama_id': 1, 'number': 1, 'title': null, 'duration_seconds': 95,
            'thumbnail_url': null, 'is_free': true, 'is_unlocked': true, 'views': 3},
          'drama': {'id': 1, 'slug': 'x', 'title': 'X', 'total_episodes': 60, 'poster_url': null},
          'next_episode_id': 6,
          'prev_episode_id': null,
        },
      }),
    }));
    final r = await PlayerService(api).play(5);
    expect(r.videoUrl, '/storage/videos/ep1.mp4');
    expect(r.nextEpisodeId, 6);
    expect(r.prevEpisodeId, isNull);
    expect(r.episode.title, '');
  });

  test('401 with a session token triggers the unauthorized callback', () async {
    final api = _client(_FakeAdapter({
      '/me/payments': (401, {'message': 'Unauthenticated.', 'code': 'unauthenticated'}),
    }))
      ..token = 'expired';
    var fired = false;
    api.onUnauthorized = () => fired = true;
    await expectLater(
      MeService(api).payments(),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
    );
    expect(fired, isTrue);
  });

  test('payment polling + subscription payloads', () async {
    final api = _client(_FakeAdapter({
      '/payments/AFR-1': (200, {
        'data': {'id': 1, 'reference': 'AFR-1', 'status': 'success', 'amount': 10000, 'currency': 'TZS',
          'payment_method': 'mpesa', 'payment_method_code': 'mpesa', 'phone': null,
          'plan': {'id': 2, 'name': 'Monthly VIP', 'type': 'monthly', 'price': 10000},
          'paid_at': '2026-01-01T10:00:00+00:00', 'created_at': '2026-01-01T09:59:00+00:00'},
      }),
      // No active subscription: data is null, details live in meta.
      '/me/subscription': (200, {'data': null, 'meta': {'is_vip': false, 'coins': 0}}),
    }));
    final p = await CommerceService(api).payment('AFR-1');
    expect(p.isSuccess, isTrue);
    expect(p.methodCode, 'mpesa');
    expect(p.planName, 'Monthly VIP');
    expect(await MeService(api).subscription(), isNull);
  });

  test('requests carry Accept-Language and local errors follow the language', () async {
    final adapter = _FakeAdapter({'/me/payments': (500, <String, dynamic>{})});
    final api = _client(adapter);
    final english = L10n.current.errorGeneric;
    L10n.setCode('sw');
    addTearDown(() => L10n.setCode('en'));
    await expectLater(
      MeService(api).payments(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', L10n.current.errorGeneric)),
    );
    expect(adapter.requests.single.headers['Accept-Language'], 'sw');
    expect(L10n.current.errorGeneric, isNot(english));
  });

  test('history entry tolerates a deleted episode', () {
    final h = HistoryEntry.fromJson({
      'id': 1,
      'drama': {'id': 3, 'slug': 's', 'title': 'T', 'categories': [], 'tags': [], 'company': null},
      'episode': null,
      'progress_seconds': 40,
      'updated_at': '2026-01-01T00:00:00+00:00',
    });
    expect(h.episodeNumber, 1);
    expect(h.episodeId, isNull);
    expect(h.drama.company, isNull);
  });
}
