import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState extends ChangeNotifier {
  AuthState({required this.api, required this.service, required this.storage}) {
    api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient api;
  final AuthService service;
  final TokenStorage storage;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isLoggedIn => _status == AuthStatus.signedIn && _user != null;
  bool get isVip => _user?.isVip ?? false;
  int get coins => _user?.coins ?? 0;

  /// Restores a persisted session. Never throws.
  Future<void> bootstrap() async {
    final token = await storage.read();
    if (token == null || token.isEmpty) {
      _setSignedOut();
      return;
    }
    api.token = token;
    try {
      _user = await service.me();
      _status = AuthStatus.signedIn;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await storage.clear();
        api.token = null;
        _setSignedOut();
      } else {
        // Offline: keep the token so the session works once we're back online.
        _status = AuthStatus.signedOut;
        notifyListeners();
      }
    }
  }

  Future<void> login(String login, String password) async {
    final res = await service.login(login: login, password: password);
    await _accept(res);
  }

  Future<void> register({
    required String name,
    String? email,
    String? phone,
    required String password,
  }) async {
    final res = await service.register(name: name, email: email, phone: phone, password: password);
    await _accept(res);
  }

  Future<void> refresh() async {
    if (!api.hasToken) return;
    try {
      _user = await service.me();
      _status = AuthStatus.signedIn;
      notifyListeners();
    } on ApiException {
      // Ignore transient errors.
    }
  }

  /// Optimistically adjust the local coin balance (e.g. after an unlock).
  void setCoins(int coins) {
    if (_user == null) return;
    _user = _user!.copyWith(coins: coins);
    notifyListeners();
  }

  Future<void> logout() async {
    await service.logout();
    await storage.clear();
    api.token = null;
    _setSignedOut();
  }

  Future<void> _accept(AuthResult res) async {
    api.token = res.token;
    await storage.write(res.token);
    _user = res.user;
    _status = AuthStatus.signedIn;
    notifyListeners();
    // Pull the full profile (coins, active subscription) in the background.
    refresh();
  }

  void _handleUnauthorized() {
    storage.clear();
    api.token = null;
    _setSignedOut();
  }

  void _setSignedOut() {
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
