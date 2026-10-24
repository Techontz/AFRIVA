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

  /// Base URL of the Afriva REST API (always ends without a trailing slash).
  static String get apiUrl {
    if (_definedApiUrl.isNotEmpty) {
      return _definedApiUrl.endsWith('/')
          ? _definedApiUrl.substring(0, _definedApiUrl.length - 1)
          : _definedApiUrl;
    }
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

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration paymentPollInterval = Duration(seconds: 3);
  static const Duration paymentPollTimeout = Duration(minutes: 3);
}
