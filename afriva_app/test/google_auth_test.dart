// "Continue with Google": hidden until configured, posts the ID token to
// /auth/google and lands signed in, shows API errors.
import 'dart:convert';

import 'package:afriva_app/core/api_client.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/auth/google_sign_in.dart';
import 'package:afriva_app/features/auth/login_screen.dart';
import 'package:afriva_app/features/auth/register_screen.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/services/auth_service.dart';
import 'package:afriva_app/services/facebook_auth.dart';
import 'package:afriva_app/services/google_auth.dart';
import 'package:afriva_app/services/me_service.dart';
import 'package:afriva_app/services/token_storage.dart';
import 'package:afriva_app/state/auth_state.dart';
import 'package:afriva_app/state/favorites_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

class _FakeFacebook implements FacebookAuth {
  _FakeFacebook(this.token);
  final String? token;
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<String?> accessToken() async {
    calls++;
    return token;
  }
}

class _FakeGoogle implements GoogleAuth {
  _FakeGoogle(this.token, {this.error});
  final String? token;
  final GoogleAuthException? error;
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<String?> idToken() async {
    calls++;
    if (error != null) throw error!;
    return token;
  }
}

const _user = {'id': 7, 'name': 'Asha Juma', 'email': 'asha@gmail.com', 'coins': 0, 'is_vip': false};

class _Harness {
  _Harness(Map<String, (int, Object?)> routes)
      : adapter = _FakeAdapter(routes),
        storage = MemoryTokenStorage() {
    api = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
    auth = AuthState(api: api, service: AuthService(api), storage: storage);
  }

  final _FakeAdapter adapter;
  final MemoryTokenStorage storage;
  late final ApiClient api;
  late final AuthState auth;

  Widget app({GoogleAuth? google, FacebookAuth? facebook, String initial = '/login'}) {
    AppTheme.init(useGoogleFonts: false);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ]);
    return MultiProvider(
      providers: [
        if (google != null) Provider<GoogleAuth>.value(value: google),
        if (facebook != null) Provider<FacebookAuth>.value(value: facebook),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => FavoritesState(MeService(api))),
      ],
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
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

final _googleButton = find.text('Continue with Google');

void main() {
  test('Google sign-in needs GOOGLE_SERVER_CLIENT_ID (and an iOS client id on iOS)', () {
    // Tests run without --dart-define, so the build default is off.
    expect(PluginGoogleAuth().isAvailable, isFalse);
    expect(PluginGoogleAuth(serverClientId: '', platform: TargetPlatform.android).isAvailable, isFalse);
    expect(PluginGoogleAuth(serverClientId: 'web.apps', platform: TargetPlatform.android).isAvailable, isTrue);
    expect(PluginGoogleAuth(serverClientId: 'web.apps', platform: TargetPlatform.iOS).isAvailable, isFalse);
    expect(
      PluginGoogleAuth(serverClientId: 'web.apps', iosClientId: 'ios.apps', platform: TargetPlatform.iOS)
          .isAvailable,
      isTrue,
    );
    expect(PluginGoogleAuth(serverClientId: 'web.apps', isWeb: true).isAvailable, isFalse);
  });

  testWidgets('Button is hidden when GOOGLE_SERVER_CLIENT_ID is empty', (tester) async {
    _phone(tester);
    final h = _Harness({});
    await tester.pumpWidget(h.app(google: PluginGoogleAuth()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(_googleButton, findsNothing);
    expect(find.byType(GoogleSignInButton), findsNothing);

    await tester.pumpWidget(h.app(google: PluginGoogleAuth(), initial: '/register'));
    await tester.pumpAndSettle();
    expect(find.byType(GoogleSignInButton), findsNothing);
  });

  testWidgets('Google sign-in posts the ID token to /auth/google and lands signed in', (tester) async {
    _phone(tester);
    final h = _Harness({
      '/auth/google': (200, {
        'data': {'token': '42|google-session', 'user': _user},
      }),
      '/auth/me': (200, {'data': _user}),
      '/me/favorites': (200, {'data': []}),
    });
    final google = _FakeGoogle('google-id-token');
    await tester.pumpWidget(h.app(google: google));
    await tester.pumpAndSettle();

    expect(find.text('or'), findsOneWidget);
    await tester.ensureVisible(_googleButton);
    await tester.tap(_googleButton);
    await tester.pumpAndSettle();

    expect(google.calls, 1);
    final req = h.adapter.requests.firstWhere((r) => r.path == '/auth/google');
    expect(req.method, 'POST');
    expect(req.data['id_token'], 'google-id-token');
    expect(req.data['device_name'], anyOf('android', 'ios'));

    expect(h.auth.isLoggedIn, isTrue);
    expect(h.auth.user!.name, 'Asha Juma');
    expect(h.api.token, '42|google-session');
    expect(await h.storage.read(), '42|google-session');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Register screen offers Google too', (tester) async {
    _phone(tester);
    final h = _Harness({
      '/auth/google': (200, {
        'data': {'token': '43|g', 'user': _user},
      }),
    });
    await tester.pumpWidget(h.app(google: _FakeGoogle('tok'), initial: '/register'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_googleButton);
    await tester.tap(_googleButton);
    await tester.pumpAndSettle();
    expect(h.auth.isLoggedIn, isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('A 401 google_failed shows the API message and stays signed out', (tester) async {
    _phone(tester);
    final h = _Harness({
      '/auth/google': (401, {'message': 'We could not verify your Google account.', 'code': 'google_failed'}),
    });
    await tester.pumpWidget(h.app(google: _FakeGoogle('bad-token')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_googleButton);
    await tester.tap(_googleButton);
    await tester.pumpAndSettle();

    expect(find.text('We could not verify your Google account.'), findsOneWidget);
    expect(h.auth.isLoggedIn, isFalse);
    expect(await h.storage.read(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Cancelling the Google picker does nothing', (tester) async {
    _phone(tester);
    final h = _Harness({});
    await tester.pumpWidget(h.app(google: _FakeGoogle(null)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_googleButton);
    await tester.tap(_googleButton);
    await tester.pumpAndSettle();
    expect(h.adapter.requests, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('Google sign-in'), findsNothing);
  });

  testWidgets('A Google configuration problem shows a localized message', (tester) async {
    _phone(tester);
    final h = _Harness({});
    await tester.pumpWidget(h.app(
      google: _FakeGoogle(null, error: const GoogleAuthException(GoogleAuthFailure.unavailable)),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_googleButton);
    await tester.tap(_googleButton);
    await tester.pumpAndSettle();
    expect(find.textContaining("Google sign-in isn't available"), findsOneWidget);
    expect(h.adapter.requests, isEmpty);
  });

  test('Facebook sign-in needs FACEBOOK_APP_ID and runs on Android only', () {
    expect(PluginFacebookAuth().isAvailable, isFalse);
    expect(PluginFacebookAuth(appId: '123', platform: TargetPlatform.android).isAvailable, isTrue);
    expect(PluginFacebookAuth(appId: '123', platform: TargetPlatform.iOS).isAvailable, isFalse);
    expect(PluginFacebookAuth(appId: '123', isWeb: true).isAvailable, isFalse);
  });

  testWidgets('Facebook sign-in posts the access token to /auth/facebook', (tester) async {
    _phone(tester);
    final h = _Harness({
      '/auth/facebook': (200, {
        'data': {'token': '44|fb-session', 'user': _user},
      }),
      '/me/favorites': (200, {'data': []}),
    });
    final facebook = _FakeFacebook('fb-access-token');
    await tester.pumpWidget(h.app(google: _FakeGoogle('g'), facebook: facebook, initial: '/register'));
    await tester.pumpAndSettle();

    final button = find.text('Continue with Facebook');
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with phone number'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(facebook.calls, 1);
    final req = h.adapter.requests.firstWhere((r) => r.path == '/auth/facebook');
    expect(req.data['access_token'], 'fb-access-token');
    expect(h.auth.isLoggedIn, isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Sign up with a phone number: no email and no verification code', (tester) async {
    _phone(tester);
    final h = _Harness({
      '/auth/register': (201, {
        'data': {'token': '45|phone', 'user': _user},
      }),
      '/me/favorites': (200, {'data': []}),
    });
    await tester.pumpWidget(h.app(google: _FakeGoogle('g'), facebook: _FakeFacebook('f'), initial: '/register'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Continue with phone number'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '0712 345 678');
    await tester.enterText(fields.at(1), 'Asha Juma');
    await tester.enterText(fields.at(2), 'secret1');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final req = h.adapter.requests.firstWhere((r) => r.path == '/auth/register');
    expect(req.data['phone'], '0712 345 678');
    expect(req.data['email'], isNull);
    expect(h.auth.isLoggedIn, isTrue);
    expect(find.text('home'), findsOneWidget);
  });
}
