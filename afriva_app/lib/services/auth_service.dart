import '../core/api_client.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthResult> login({required String login, required String password}) async {
    final data = await _api.post('/auth/login', body: {'login': login.trim(), 'password': password});
    return AuthResult.fromJson(asMap(data));
  }

  Future<AuthResult> register({
    required String name,
    String? email,
    String? phone,
    required String password,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'name': name.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'password': password,
      'password_confirmation': password,
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<User> me() async {
    final data = asMap(await _api.get('/auth/me'));
    // Accept both `{data:{user}}` and `{data:user}`.
    return User.fromJson(data['user'] is Map ? asMap(data['user']) : data);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Token may already be invalid; the local session is cleared regardless.
    }
  }
}
