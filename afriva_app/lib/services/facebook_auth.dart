import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart' as fb;

import '../core/config.dart';

/// Why Facebook Login failed (cancelling is not an error: it resolves to null).
enum FacebookAuthFailure { unavailable, failed }

class FacebookAuthException implements Exception {
  const FacebookAuthException(this.reason, [this.detail]);
  final FacebookAuthFailure reason;
  final String? detail;

  @override
  String toString() => 'FacebookAuthException($reason): ${detail ?? ''}';
}

/// Gets a Facebook Login access token for the API's `POST /auth/facebook`.
///
/// Abstract so widget tests can inject a fake.
abstract class FacebookAuth {
  /// False hides the "Continue with Facebook" button.
  bool get isAvailable;

  /// Opens Facebook Login and returns the access token, or null when the
  /// viewer cancels. Throws [FacebookAuthException] on any other failure.
  Future<String?> accessToken();
}

/// [FacebookAuth] backed by the `flutter_facebook_auth` plugin.
class PluginFacebookAuth implements FacebookAuth {
  PluginFacebookAuth({String appId = AppConfig.facebookAppId, TargetPlatform? platform, this.isWeb = kIsWeb})
      : _appId = appId.trim(),
        _platform = platform ?? defaultTargetPlatform;

  final String _appId;
  final TargetPlatform _platform;
  final bool isWeb;

  @override
  bool get isAvailable => !isWeb && _appId.isNotEmpty && _platform == TargetPlatform.android;

  @override
  Future<String?> accessToken() async {
    if (!isAvailable) throw const FacebookAuthException(FacebookAuthFailure.unavailable);
    final sdk = fb.FacebookAuth.instance;
    try {
      final result = await sdk.login(permissions: const ['public_profile', 'email']);
      switch (result.status) {
        case fb.LoginStatus.success:
          final token = result.accessToken?.tokenString;
          // Afriva keeps its own session; drop Facebook's so the next login asks again.
          sdk.logOut().catchError((_) {});
          if (token == null || token.isEmpty) throw const FacebookAuthException(FacebookAuthFailure.failed);
          return token;
        case fb.LoginStatus.cancelled:
          return null;
        default:
          throw FacebookAuthException(FacebookAuthFailure.failed, result.message);
      }
    } on FacebookAuthException {
      rethrow;
    } catch (e) {
      throw FacebookAuthException(FacebookAuthFailure.failed, '$e');
    }
  }
}
