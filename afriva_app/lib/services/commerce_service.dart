import '../core/api_client.dart';
import '../core/payments.dart';
import '../models/commerce.dart';
import '../models/json.dart';

class CommerceService {
  CommerceService(this._api);
  final ApiClient _api;

  Future<List<Plan>> plans() async => asList(await _api.get('/plans'), Plan.fromJson);

  /// Which channels (mobile money, card) can take payments right now.
  Future<CheckoutOptions> checkoutOptions() async =>
      CheckoutOptions.fromJson(asMap(await _api.get('/checkout/options')));

  /// Mobile money: the server picks the network from the number prefix.
  Future<CheckoutResult> payWithMobileMoney({required int planId, required String phone, bool save = true}) =>
      _checkout({'plan_id': planId, 'channel': 'mobile_money', 'phone': phone, 'save': save});

  /// Card: only brand, last 4 digits, expiry and (later) a provider token are
  /// sent. The full number and CVC never reach the Afriva API.
  Future<CheckoutResult> payWithCard({required int planId, required CardPayload card, bool save = true}) =>
      _checkout({'plan_id': planId, 'channel': 'card', 'card': card.toJson(), 'save': save});

  /// Hosted card: no card details at all. The viewer types the card on the
  /// payment partner's secure page (`redirect_url`); the phone is for the receipt.
  Future<CheckoutResult> payWithHostedCard({required int planId, required String phone}) =>
      _checkout({'plan_id': planId, 'channel': 'card', 'phone': phone});

  /// One tap with a saved number or card.
  Future<CheckoutResult> payWithSaved({required int planId, required int savedMethodId}) =>
      _checkout({'plan_id': planId, 'saved_method_id': savedMethodId});

  /// Google Play: the server checks the purchase token with Google, then activates the plan.
  Future<Payment> verifyPlayPurchase({required String productId, required String purchaseToken}) async {
    final data = asMap(await _api.post('/payments/google-play', body: {
      'product_id': productId,
      'purchase_token': purchaseToken,
    }));
    return Payment.fromJson(data['payment'] is Map ? asMap(data['payment']) : data);
  }

  Future<CheckoutResult> _checkout(Map<String, dynamic> body) async =>
      CheckoutResult.fromJson(asMap(await _api.post('/checkout', body: body)));

  Future<Payment> payment(String reference) async {
    final data = asMap(await _api.get('/payments/$reference'));
    return Payment.fromJson(data['payment'] is Map ? asMap(data['payment']) : data);
  }

  Future<List<SavedMethod>> savedMethods() async =>
      asList(await _api.get('/me/payment-methods'), SavedMethod.fromJson);

  Future<SavedMethod> addNumber(String phone) async =>
      SavedMethod.fromJson(asMap(await _api.post('/me/payment-methods', body: {'phone': phone})));

  Future<void> makeDefault(int id) => _api.patchJson('/me/payment-methods/$id');

  Future<void> removeMethod(int id) => _api.deleteJson('/me/payment-methods/$id');
}
