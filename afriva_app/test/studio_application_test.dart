// "Request to post": percentage formatting, API payloads, guidelines and form.
import 'dart:convert';
import 'dart:typed_data';

import 'package:afriva_app/core/api_client.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/profile/profile_screen.dart';
import 'package:afriva_app/features/studio/creator_guidelines_sheet.dart';
import 'package:afriva_app/features/studio/studio_application_screen.dart';
import 'package:afriva_app/features/studio/studio_status_screen.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/studio_application.dart';
import 'package:afriva_app/services/auth_service.dart';
import 'package:afriva_app/services/studio_service.dart';
import 'package:afriva_app/services/token_storage.dart';
import 'package:afriva_app/state/auth_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

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

Future<void> _apply(StudioService s) => s.apply(
      fullName: 'Asha Juma',
      idType: 'nida',
      idNumber: '19900101-12345',
      phone: '0712 345 678',
      payoutMethod: 'mobile_money',
      payoutProvider: 'mpesa',
      payoutBankName: 'Ignored Bank',
      payoutAccountName: 'Asha Juma',
      payoutAccountNumber: '0712345678',
      email: 'asha@example.com',
      password: 'secret123',
    );

Widget _wrap(Widget child, {ApiClient? api}) {
  final client = api ?? _client(_FakeAdapter({}));
  return MultiProvider(
    providers: [
      Provider<StudioService>.value(value: StudioService(client)),
      ChangeNotifierProvider(
        create: (_) => AuthState(api: client, service: AuthService(client), storage: MemoryTokenStorage()),
      ),
    ],
    child: MaterialApp(
      theme: (() {
        AppTheme.init(useGoogleFonts: false);
        return AppTheme.dark;
      })(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: child,
    ),
  );
}

void main() {
  test('percentages are shown without a trailing .0', () {
    expect(formatPercent(60), '60');
    expect(formatPercent(60.0), '60');
    expect(formatPercent(62.5), '62.5');
    expect(formatPercent(33.333), '33.33');
    expect(formatPercent(40.10), '40.1');
    final split = RevenueSplit.fromJson({'creator_percent': '70.0', 'platform_percent': 30});
    expect(split.creatorLabel, '70');
    expect(split.platformLabel, '30');
  });

  test('validators mirror the API rules', () {
    expect(StudioValidators.idNumber('AB-12 34'), isTrue);
    expect(StudioValidators.idNumber('123'), isFalse);
    expect(StudioValidators.idNumber('12#45'), isFalse);
    expect(StudioValidators.phone('+255 712 345 678'), isTrue);
    expect(StudioValidators.phone('07123'), isFalse);
    expect(StudioValidators.phone('0712-345-678'), isFalse);
  });

  test('guest apply sends email + password; signed-in apply does not', () async {
    final adapter = _FakeAdapter({
      '/auth/studio-application': (201, {
        'data': {
          'status': 'pending',
          'existing_user': true,
          'company': {'id': 3, 'name': 'Asha Films'},
        },
        'meta': {'message': 'Received'},
      }),
    });
    final api = _client(adapter);
    final service = StudioService(api);

    await _apply(service);
    var body = adapter.requests.last.data as Map;
    expect(body['email'], 'asha@example.com');
    expect(body['password'], 'secret123');
    expect(body['payout_provider'], 'mpesa');
    expect(body.containsKey('payout_bank_name'), isFalse);
    expect(body['guidelines_accepted'], isTrue);

    api.token = 'tok';
    await _apply(service);
    body = adapter.requests.last.data as Map;
    expect(body.containsKey('email'), isFalse);
    expect(body.containsKey('password'), isFalse);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer tok');
  });

  test('my application parses null and full payloads', () async {
    final none = StudioService(_client(_FakeAdapter({'/me/studio-application': (200, {'data': null})})));
    expect(await none.myApplication(), isNull);

    final full = StudioService(_client(_FakeAdapter({
      '/me/studio-application': (200, {
        'data': {
          'status': 'pending',
          'review_status': 'ready_for_review',
          'rejection_reason': null,
          'company': {'id': 3, 'name': 'Asha Films', 'status': 'pending'},
          'samples': [
            {'id': 1, 'title': 'Pilot', 'status': 'ready', 'duration_seconds': 125, 'length_check': 'ok', 'valid': true},
            {'id': 2, 'title': 'Teaser', 'status': 'ready', 'duration_seconds': 40, 'length_check': 'too_short', 'valid': false},
          ],
          'samples_summary': {'required': 10, 'uploaded': 2, 'valid': 1, 'min_seconds': 60, 'max_seconds': 180},
          'revenue_split': {'creator_percent': 60, 'platform_percent': 40},
          'created_at': '2026-10-01T10:00:00Z',
          'reviewed_at': null,
        },
      }),
    })));
    final app = (await full.myApplication())!;
    expect(app.effectiveStatus, 'ready_for_review');
    expect(app.companyName, 'Asha Films');
    expect(app.samples, hasLength(2));
    expect(app.samples[1].lengthCheck, 'too_short');
    expect(app.summary.valid, 1);
    expect(app.revenueSplit!.creatorLabel, '60');
  });

  testWidgets('guidelines show the percentages from the API', (tester) async {
    await tester.pumpWidget(_wrap(Scaffold(
      body: CreatorGuidelinesView(
        load: () async => const RevenueSplit(creatorPercent: 62.5, platformPercent: 37.5),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Afriva creator guidelines'), findsOneWidget);
    expect(find.textContaining('you receive 62.5% of the revenue'), findsOneWidget);
    expect(find.textContaining('Afriva keeps 37.5%.'), findsOneWidget);
  });

  testWidgets('form: submit disabled until guidelines accepted; guests see login fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const StudioApplicationScreen()));
    await tester.pump();

    expect(find.text('Full names as on your ID'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Submit does nothing until the checkbox is ticked.
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    expect(find.text('This field is required'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    expect(find.text('This field is required'), findsWidgets);
    expect(find.text('Choose a provider'), findsOneWidget);

    // Bank payout swaps the provider for a bank name field.
    await tester.tap(find.text('Bank'));
    await tester.pump();
    expect(find.text('Bank name'), findsOneWidget);
    expect(find.text('Mobile money provider'), findsNothing);
  });

  testWidgets('status view lists samples with length marks', (tester) async {
    await tester.pumpWidget(_wrap(Scaffold(
      body: StudioStatusView(
        application: StudioApplication.fromJson({
          'status': 'rejected',
          'review_status': 'rejected',
          'rejection_reason': 'Blurry samples',
          'samples': [
            {'id': 1, 'title': 'Teaser', 'status': 'ready', 'duration_seconds': 40, 'length_check': 'too_short'},
          ],
          'samples_summary': {'required': 10, 'uploaded': 1, 'valid': 0},
        }),
      ),
    )));
    await tester.pump();
    expect(find.text('Not approved'), findsOneWidget);
    expect(find.text('Reason: Blurry samples'), findsOneWidget);
    expect(find.text('Too short'), findsOneWidget);
    expect(find.textContaining('00:40'), findsOneWidget);
  });

  testWidgets('profile shows Request to post, with status when signed in', (tester) async {
    final adapter = _FakeAdapter({
      '/auth/login': (200, {
        'data': {
          'token': 'tok',
          'user': {'id': 7, 'name': 'Asha', 'role': 'company', 'status': 'pending'},
        },
      }),
      '/auth/me': (200, {
        'data': {'id': 7, 'name': 'Asha', 'role': 'company', 'status': 'pending'},
      }),
      '/me/studio-application': (200, {
        'data': {
          'status': 'pending',
          'review_status': 'pending',
          'samples': [],
          'samples_summary': {'required': 10, 'uploaded': 3, 'valid': 3},
        },
      }),
    });
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _client(adapter);
    await tester.pumpWidget(_wrap(const ProfileScreen(), api: api));
    await tester.pump();
    expect(find.text('Request to post'), findsOneWidget);
    expect(find.textContaining('Samples'), findsNothing);

    final auth = tester.element(find.byType(ProfileScreen)).read<AuthState>();
    expect(auth.isLoggedIn, isFalse);
    await tester.runAsync(() async {
      await auth.login('asha@example.com', 'secret123');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(auth.user!.isPendingStudio, isTrue);
    // Rebuild (registers the new user), then let the HTTP call finish for real.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump();
    expect(find.text('Request to post'), findsOneWidget);
    expect(find.textContaining('Pending review'), findsOneWidget);
    expect(find.textContaining('Samples 3/10'), findsOneWidget);
  });
}
