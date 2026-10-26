import '../core/api_client.dart';
import '../models/commerce.dart';
import '../models/json.dart';

class CommerceService {
  CommerceService(this._api);
  final ApiClient _api;

  Future<List<Plan>> plans() async => asList(await _api.get('/plans'), Plan.fromJson);

  Future<List<PaymentMethod>> paymentMethods() async =>
      asList(await _api.get('/payment-methods'), PaymentMethod.fromJson)
          .where((m) => m.isEnabled)
          .toList();

  /// [idempotencyKey] identifies one checkout attempt: retrying with the same key
  /// (e.g. after a network drop) returns the original payment instead of charging twice.
  Future<CheckoutResult> checkout({
    required int planId,
    required String paymentMethod,
    String? phone,
    Map<String, dynamic>? card,
    String? idempotencyKey,
  }) async {
    final data = await _api.post('/checkout', body: {
      'plan_id': planId,
      'payment_method': paymentMethod,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'card': ?card,
    }, headers: idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey});
    return CheckoutResult.fromJson(asMap(data));
  }

  Future<Receipt> receipt(String reference) async =>
      Receipt.fromJson(asMap(await _api.get('/me/payments/$reference/receipt')));

  Future<Payment> payment(String reference) async {
    final data = asMap(await _api.get('/payments/$reference'));
    return Payment.fromJson(data['payment'] is Map ? asMap(data['payment']) : data);
  }
}
