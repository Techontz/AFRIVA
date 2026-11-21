import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';

/// Why getting a Google ID token failed (cancelling is not an error: it
/// resolves to null instead).
enum GoogleAuthFailure { unavailable, failed }

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.reason, [this.detail]);
  final GoogleAuthFailure reason;
  final String? detail;

  @override
  String toString() => 'GoogleAuthException($reason): ${detail ?? ''}';
}

/// Gets a Google ID token for the API's `POST /auth/google`.
///
/// Abstract so widget tests can inject a fake.
abstract class GoogleAuth {
  /// False hides the "Continue with Google" button.
  bool get isAvailable;

  /// Shows Google's account picker and returns the ID token, or null when the
  /// viewer cancels. Throws [GoogleAuthException] on any other failure.
  Future<String?> idToken();
}

/// [GoogleAuth] backed by the official `google_sign_in` plugin (v7 API).
class PluginGoogleAuth implements GoogleAuth {
  PluginGoogleAuth({
    String serverClientId = AppConfig.googleServerClientId,
    String iosClientId = AppConfig.googleIosClientId,
    TargetPlatform? platform,
    this.isWeb = kIsWeb,
  })  : _serverClientId = serverClientId.trim(),
        _iosClientId = iosClientId.trim(),
        _platform = platform ?? defaultTargetPlatform;

  final String _serverClientId;
  final String _iosClientId;
  final TargetPlatform _platform;
  final bool isWeb;
  Future<void>? _init;

  @override
  bool get isAvailable {
    if (isWeb || _serverClientId.isEmpty) return false;
    return switch (_platform) {
      TargetPlatform.android => true,
      // iOS has no google-services file here, so it needs its own client id.
      TargetPlatform.iOS => _iosClientId.isNotEmpty,
      _ => false,
    };
  }

  Future<void> _ensureInitialized() => _init ??= GoogleSignIn.instance
      .initialize(
        serverClientId: _serverClientId,
        clientId: _platform == TargetPlatform.iOS ? _iosClientId : null,
      )
      .catchError((Object e) {
        _init = null; // Allow a retry after a transient failure.
        throw e;
      });

  @override
  Future<String?> idToken() async {
    if (!isAvailable) throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    final signIn = GoogleSignIn.instance;
    try {
      await _ensureInitialized();
      if (!signIn.supportsAuthenticate()) {
        throw const GoogleAuthException(GoogleAuthFailure.unavailable);
      }
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      // Afriva keeps its own session; drop Google's so the account picker
      // shows again next time (e.g. after logging out to switch accounts).
      signIn.signOut().catchError((_) {});
      if (token == null || token.isEmpty) {
        throw const GoogleAuthException(GoogleAuthFailure.failed, 'No ID token returned');
      }
      return token;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
        case GoogleSignInExceptionCode.uiUnavailable:
          debugPrint('[google] ${e.code}: ${e.description}');
          throw GoogleAuthException(GoogleAuthFailure.unavailable, e.description);
        default:
          debugPrint('[google] ${e.code}: ${e.description}');
          throw GoogleAuthException(GoogleAuthFailure.failed, e.description);
      }
    } on GoogleAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[google] $e');
      throw GoogleAuthException(GoogleAuthFailure.failed, e.toString());
    }
  }
}
