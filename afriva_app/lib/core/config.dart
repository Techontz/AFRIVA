import 'package:flutter/foundation.dart';

/// App-wide configuration.
///
/// The API base URL can be overridden at build time:
/// `flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1`
class AppConfig {
  AppConfig._();

  static const String appName = 'Afriva';
  static const String currency = 'TZS';

  static const String _definedApiUrl = String.fromEnvironment('API_URL');

  /// Production API, used by release builds when API_URL is not defined.
  static const String productionApiUrl = 'https://api.afriva.co.tz/api/v1';

  /// Base URL of the Afriva REST API (always ends without a trailing slash).
  static String get apiUrl {
    if (_definedApiUrl.isNotEmpty) {
      return _definedApiUrl.endsWith('/')
          ? _definedApiUrl.substring(0, _definedApiUrl.length - 1)
          : _definedApiUrl;
    }
    if (kReleaseMode) return productionApiUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator loopback to the host machine.
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  /// Origin of the API (scheme + host + port), used to resolve relative
  /// media paths such as `/storage/videos/ep1.mp4`.
  static String get apiOrigin {
    final uri = Uri.parse(apiUrl);
    return uri.replace(path: '', query: null, fragment: null).toString().replaceAll(RegExp(r'/$'), '');
  }

  /// Resolves possibly-relative media URLs coming from the API.
  static String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // The API may emit localhost URLs which the Android emulator can't reach.
      if (!kIsWeb &&
          !kReleaseMode &&
          defaultTargetPlatform == TargetPlatform.android &&
          _definedApiUrl.isEmpty) {
        return url
            .replaceFirst('://localhost', '://10.0.2.2')
            .replaceFirst('://127.0.0.1', '://10.0.2.2');
      }
      return url;
    }
    if (url.startsWith('//')) return 'https:$url';
    return '$apiOrigin${url.startsWith('/') ? '' : '/'}$url';
  }

  /// Google Sign-In, set at build time:
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (required: Android
  /// only returns an ID token for a web client, and the API verifies it) and
  /// `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>` (required on iOS).
  /// While the server id is empty the "Continue with Google" button is hidden.
  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Facebook Login, set at build time with `--dart-define=FACEBOOK_APP_ID=...`
  /// and `--dart-define=FACEBOOK_CLIENT_TOKEN=...` (both from developers.facebook.com).
  /// While the app id is empty the "Continue with Facebook" button is hidden.
  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration paymentPollInterval = Duration(seconds: 3);
  static const Duration paymentPollTimeout = Duration(minutes: 2);

  /// Hosted card page: typing a card and passing 3-D Secure takes longer.
  static const Duration hostedCardPollTimeout = Duration(minutes: 5);
}
