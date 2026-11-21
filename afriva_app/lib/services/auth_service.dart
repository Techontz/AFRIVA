import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/disk_cache.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthResult> login({required String login, required String password}) async {
    final data = await _api.post('/auth/login', body: {'login': login.trim(), 'password': password});
    return AuthResult.fromJson(asMap(data));
  }

  /// Exchanges a Google ID token for an Afriva session (same payload as login).
  Future<AuthResult> google({required String idToken}) async {
    final data = await _api.post('/auth/google', body: {
      'id_token': idToken,
      'device_name': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<AuthResult> facebook({required String accessToken}) async {
    final data = await _api.post('/auth/facebook', body: {
      'access_token': accessToken,
      'device_name': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
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

  static const _userKey = 'auth.user';

  Future<User> me() async {
    final data = asMap(await _api.get('/auth/me'));
    // Accept both `{data:{user}}` and `{data:user}`.
    final json = data['user'] is Map ? asMap(data['user']) : data;
    DiskCache.write(_userKey, json);
    return User.fromJson(json);
  }

  /// The profile saved by the last successful [me], for an instant start.
  User? cachedUser() {
    final json = DiskCache.read(_userKey);
    if (json is! Map) return null;
    try {
      return User.fromJson(asMap(json));
    } catch (_) {
      return null;
    }
  }

  void forgetUser() => DiskCache.remove(_userKey);

  Future<void> deleteAccount() async {
    await _api.deleteJson('/me');
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Token may already be invalid; the local session is cleared regardless.
    }
  }
}
