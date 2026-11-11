// Payments: network detection from the number, on-device card checks, and
// the checkout screen never sending a card number or CVC to the API.
import 'dart:convert';
import 'dart:typed_data';

import 'package:afriva_app/core/api_client.dart';
import 'package:afriva_app/core/payments.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/vip/checkout_screen.dart';
import 'package:afriva_app/features/vip/payment_widgets.dart';
import 'package:afriva_app/features/vip/phone_field.dart';
import 'package:afriva_app/l10n/l10n.dart';
import 'package:afriva_app/models/commerce.dart';
import 'package:afriva_app/services/auth_service.dart';
import 'package:afriva_app/services/commerce_service.dart';
import 'package:afriva_app/services/token_storage.dart';
import 'package:afriva_app/state/auth_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final (int, Object?) Function(RequestOptions o) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> posts(String path) => requests.where((r) => r.method == 'POST' && r.path == path).toList();
}

class _NoStorage implements TokenStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

const _plan = Plan(id: 3, name: 'VIP Monthly', type: 'monthly', price: 9900, durationDays: 30);

Map<String, dynamic> _options({bool mm = true, bool card = true}) => {
      'data': {
        'mobile_money': {
          'available': mm,
          'networks': [
            {'code': 'mpesa', 'name': 'M-Pesa', 'available': mm},
            {'code': 'airtelmoney', 'name': 'Airtel Money', 'available': mm},
          ],
        },
        'card': {
          'available': card,
          'brands': [
            {'code': 'visa', 'name': 'Visa', 'available': card},
            {'code': 'mastercard', 'name': 'Mastercard', 'available': card},
          ],
        },
        'demo': false,
      },
    };

Map<String, dynamic> _payment(String status, {String method = 'visa', String? phone}) => {
      'reference': 'AFR-TEST1',
      'status': status,
      'amount': 9900,
      'currency': 'TZS',
      'payment_method': method,
      'phone': phone,
    };

Widget _app(_Adapter adapter, Widget home) {
  AppTheme.init(useGoogleFonts: false);
  final api = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
  return MultiProvider(
    providers: [
      Provider(create: (_) => CommerceService(api)),
      ChangeNotifierProvider(create: (_) => AuthState(api: api, service: AuthService(api), storage: _NoStorage())),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: home,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('mobile network detection', () {
    test('every Tanzanian prefix maps to its network', () {
      const cases = {
        '74': 'M-Pesa', '75': 'M-Pesa', '76': 'M-Pesa', '79': 'M-Pesa',
        '68': 'Airtel Money', '69': 'Airtel Money', '78': 'Airtel Money',
        '65': 'Mixx by Yas', '67': 'Mixx by Yas', '71': 'Mixx by Yas', '77': 'Mixx by Yas',
        '61': 'HaloPesa', '62': 'HaloPesa',
        '73': 'T-Pesa',
      };
      cases.forEach((prefix, name) {
        expect(TzPhone.detect('0${prefix}1234567')?.name, name, reason: '0$prefix');
        expect(TzPhone.detect('${prefix}1234567')?.name, name, reason: prefix);
        expect(TzPhone.detect('+255 $prefix 123 4567')?.name, name, reason: '+255 $prefix');
      });
    });

    test('detects from the first two digits and ignores unknown prefixes', () {
      expect(TzPhone.detect('07'), isNull);
      expect(TzPhone.detect('075'), MobileNetwork.mpesa);
      expect(TzPhone.detect('0701234567'), isNull);
      expect(TzPhone.detect('0601234567'), isNull);
    });

    test('normalises 07.., 7.. and +255 to 255XXXXXXXXX', () {
      expect(TzPhone.normalize('0754 123 456'), '255754123456');
      expect(TzPhone.normalize('754123456'), '255754123456');
      expect(TzPhone.normalize('+255 754 123 456'), '255754123456');
      expect(TzPhone.normalize('075412345'), isNull);
      expect(TzPhone.normalize('0854123456'), isNull);
      expect(TzPhone.pretty('255754123456'), '+255 754 123 456');
    });

    testWidgets('the phone field shows the network live while typing', (tester) async {
      AppTheme.init(useGoogleFonts: false);
      final c = TextEditingController();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MobileMoneyField(controller: c)),
      ));
      expect(find.byType(NetworkPill), findsNothing);
      await tester.enterText(find.byType(TextFormField), '06');
      await tester.pump();
      expect(find.byType(NetworkPill), findsNothing);
      await tester.enterText(find.byType(TextFormField), '068');
      await tester.pumpAndSettle();
      expect(find.text('Airtel Money'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0754123456');
      await tester.pumpAndSettle();
      expect(find.text('M-Pesa'), findsOneWidget);
      expect(c.text, '754 123 456');
      await tester.enterText(find.byType(TextFormField), '0701234567');
      await tester.pumpAndSettle();
      expect(find.byType(NetworkPill), findsNothing);
      expect(find.text("We don't recognise this network yet"), findsOneWidget);
      c.dispose();
    });
  });

  group('card validation', () {
    final now = DateTime(2026, 11, 11);

    test('Luhn', () {
      expect(CardValidator.luhn('4242 4242 4242 4242'), isTrue);
      expect(CardValidator.luhn('4242 4242 4242 4241'), isFalse);
    });

    test('brand: 4 is Visa, 51-55 and 2221-2720 are Mastercard, others rejected', () {
      expect(CardValidator.brandOf('4111'), CardBrand.visa);
      for (final p in ['51', '53', '55', '2221', '2500', '2720']) {
        expect(CardValidator.brandOf('${p}00'), CardBrand.mastercard, reason: p);
      }
      for (final p in ['50', '56', '2220', '2721', '34', '6011', '35']) {
        expect(CardValidator.brandOf('${p}00'), isNull, reason: p);
      }
      expect(CardValidator.number('3782 822463 10005'), CardError.brand); // Amex
      expect(CardValidator.number('6011 1111 1111 1117'), CardError.brand); // Discover
      expect(CardValidator.number('5555 5555 5555 4444'), isNull);
      expect(CardValidator.number('2223 0031 2200 3222'), isNull);
      expect(CardValidator.number('4242 4242 4242 4241'), CardError.number);
    });

    test('expiry must not be in the past; CVC is 3 digits', () {
      expect(CardValidator.expiry('11', '26', now: now), isNull);
      expect(CardValidator.expiry('10', '26', now: now), CardError.expired);
      expect(CardValidator.expiry('01', '25', now: now), CardError.expired);
      expect(CardValidator.expiry('13', '28', now: now), CardError.month);
      expect(CardValidator.expiry('12', '2', now: now), CardError.year);
      expect(CardValidator.cvc('123'), isNull);
      expect(CardValidator.cvc('12'), CardError.cvc);
      expect(CardValidator.cvc('1234'), CardError.cvc);
    });

    test('the payload carries only brand, last 4 and expiry', () {
      final p = CardPayload.fromInput(number: '4242 4242 4242 4242', month: '12', year: '28', cvc: '987', now: now)!;
      final json = p.toJson();
      expect(json, {'brand': 'visa', 'last4': '4242', 'exp_month': 12, 'exp_year': 2028});
      final encoded = jsonEncode(json);
      expect(encoded, isNot(contains('4242424242424242')));
      expect(encoded, isNot(contains('987')));
      expect(CardPayload.fromInput(number: '4242 4242 4242 4242', month: '12', year: '28', cvc: '9', now: now), isNull);
    });
  });

  group('checkout screen', () {
    testWidgets('card checkout sends brand, last4 and expiry, never the number or CVC', (tester) async {
      _phone(tester);
      final adapter = _Adapter((o) => switch (o.path) {
            '/checkout/options' => (200, _options()),
            '/me/payment-methods' => (200, {'data': []}),
            '/checkout' => (201, {
                'data': {'payment': _payment('success'), 'message': 'Payment successful.', 'next_action': 'none'},
              }),
            _ => (404, {'message': 'Not found'}),
          });
      await tester.pumpWidget(_app(adapter, const CheckoutScreen(plan: _plan)));
      await tester.pumpAndSettle();

      expect(find.text('Mobile money'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Bank'), findsNothing);
      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('card-number')), '4242424242424242');
      await tester.enterText(find.byKey(const ValueKey('card-month')), '12');
      await tester.enterText(find.byKey(const ValueKey('card-year')), '30');
      await tester.enterText(find.byKey(const ValueKey('card-cvc')), '987');
      await tester.pumpAndSettle();
      expect(find.byType(BrandMark), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('pay')));
      await tester.pumpAndSettle();

      final posts = adapter.posts('/checkout');
      expect(posts, hasLength(1));
      final body = posts.single.data as Map<String, dynamic>;
      expect(body['channel'], 'card');
      expect(body['plan_id'], 3);
      expect(body['save'], isTrue);
      expect(body['card'], {'brand': 'visa', 'last4': '4242', 'exp_month': 12, 'exp_year': 2030});
      final raw = jsonEncode(body);
      for (final banned in ['4242424242424242', '4242 4242', '987', 'number', 'pan', 'cvc', 'cvv']) {
        expect(raw, isNot(contains(banned)), reason: banned);
      }
      expect(find.text('Welcome to VIP!'), findsOneWidget);
    });

    testWidgets('mobile money: only a number, then the check-your-phone pop-up polls to success', (tester) async {
      _phone(tester);
      var polls = 0;
      final adapter = _Adapter((o) => switch (o.path) {
            '/checkout/options' => (200, _options()),
            '/me/payment-methods' => (200, {'data': []}),
            '/checkout' => (201, {
                'data': {
                  'payment': _payment('pending', method: 'mpesa', phone: '255754123456'),
                  'message': 'Check your phone',
                  'next_action': 'await_ussd',
                },
              }),
            '/payments/AFR-TEST1' => (200, {
                'data': _payment(++polls >= 2 ? 'success' : 'pending', method: 'mpesa', phone: '255754123456'),
              }),
            _ => (404, {'message': 'Not found'}),
          });
      await tester.pumpWidget(_app(adapter, const CheckoutScreen(plan: _plan)));
      await tester.pumpAndSettle();

      // No network picker: just the number.
      expect(find.text('Airtel Money'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('mm-phone')), '0754123456');
      await tester.pumpAndSettle();
      expect(find.text('M-Pesa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final body = adapter.posts('/checkout').single.data as Map<String, dynamic>;
      expect(body, {'plan_id': 3, 'channel': 'mobile_money', 'phone': '255754123456', 'save': true});

      expect(find.text('Check your phone'), findsOneWidget);
      expect(find.text('+255 754 123 456'), findsOneWidget);
      expect(find.textContaining('Afriva will never ask for your PIN'), findsOneWidget);
      // The pop-up has no input at all: the PIN goes on the phone's own prompt.
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.byType(EditableText)), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Payment received'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to VIP!'), findsOneWidget);
    });

    testWidgets('saved default is preselected and pays with one tap; disabled channels say Coming soon',
        (tester) async {
      _phone(tester);
      final adapter = _Adapter((o) => switch (o.path) {
            '/checkout/options' => (200, _options(card: false)),
            '/me/payment-methods' => (200, {
                'data': [
                  {
                    'id': 7, 'type': 'mobile_money', 'method_code': 'airtelmoney', 'network': 'Airtel Money',
                    'phone': '255684000111', 'is_default': true, 'is_expired': false, 'one_tap': true,
                  },
                ],
              }),
            '/checkout' => (201, {
                'data': {'payment': _payment('success', method: 'airtelmoney'), 'message': 'ok', 'next_action': 'none'},
              }),
            _ => (404, {'message': 'Not found'}),
          });
      await tester.pumpWidget(_app(adapter, const CheckoutScreen(plan: _plan)));
      await tester.pumpAndSettle();

      expect(find.text('Airtel Money'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-new')));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-7')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pay')));
      await tester.pumpAndSettle();
      expect(adapter.posts('/checkout').single.data, {'plan_id': 3, 'saved_method_id': 7});
      expect(find.text('Welcome to VIP!'), findsOneWidget);
    });
  });
}
