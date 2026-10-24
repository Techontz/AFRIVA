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

  Future<CheckoutResult> checkout({
    required int planId,
    required String paymentMethod,
    String? phone,
    Map<String, dynamic>? card,
  }) async {
    final data = await _api.post('/checkout', body: {
      'plan_id': planId,
      'payment_method': paymentMethod,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'card': ?card,
    });
    return CheckoutResult.fromJson(asMap(data));
  }

  Future<Payment> payment(String reference) async {
    final data = asMap(await _api.get('/payments/$reference'));
    return Payment.fromJson(data['payment'] is Map ? asMap(data['payment']) : data);
  }
}
