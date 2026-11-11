import '../core/api_client.dart';
import '../models/json.dart';
import '../models/studio_application.dart';

/// Creator ("Request to post") endpoints.
class StudioService {
  StudioService(this._api);
  final ApiClient _api;

  bool get isLoggedIn => _api.hasToken;

  Future<RevenueSplit> guidelines() async => RevenueSplit.fromJson(asMap(await _api.get('/creator-guidelines')));

  /// Returns null when the signed-in user has not applied yet.
  Future<StudioApplication?> myApplication() async {
    final data = asMapOrNull(await _api.get('/me/studio-application'));
    if (data == null || data.isEmpty) return null;
    return StudioApplication.fromJson(data);
  }

  /// Submits a studio request. [email] and [password] are only sent when
  /// signed out (the API rejects them for signed-in users).
  Future<StudioApplyResult> apply({
    required String fullName,
    required String idType,
    required String idNumber,
    required String phone,
    required String payoutMethod,
    String? payoutProvider,
    String? payoutBankName,
    required String payoutAccountName,
    required String payoutAccountNumber,
    String? studioName,
    String? email,
    String? password,
  }) async {
    final mobile = payoutMethod == 'mobile_money';
    final body = await _api.postJson('/auth/studio-application', body: {
      'full_name': fullName.trim(),
      'id_type': idType,
      'id_number': idNumber.trim(),
      'phone': phone.trim(),
      'payout_method': payoutMethod,
      if (mobile && payoutProvider != null) 'payout_provider': payoutProvider,
      if (!mobile && payoutBankName != null) 'payout_bank_name': payoutBankName.trim(),
      'payout_account_name': payoutAccountName.trim(),
      'payout_account_number': payoutAccountNumber.trim(),
      if (studioName != null && studioName.trim().isNotEmpty) 'studio_name': studioName.trim(),
      'guidelines_accepted': true,
      if (!isLoggedIn && email != null) 'email': email.trim(),
      if (!isLoggedIn && password != null) 'password': password,
    });
    final data = asMap(body['data']);
    return StudioApplyResult(
      status: asString(data['status'], 'pending'),
      existingUser: asBool(data['existing_user']),
      message: asStringOrNull(asMap(body['meta'])['message']),
    );
  }
}
