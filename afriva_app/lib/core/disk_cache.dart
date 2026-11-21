import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small JSON cache on the device, so the app can show the last known screen
/// instantly on launch and refresh it from the API in the background.
///
/// [init] runs once in `main`; until then (and in tests) reads return null and
/// writes are skipped.
class DiskCache {
  DiskCache._();

  static SharedPreferences? _prefs;
  static const _prefix = 'cache.';

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
  }

  static Object? read(String key) {
    final raw = _prefs?.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static void write(String key, Object? value) {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {
      // Not JSON encodable: skip caching.
    }
  }

  static void remove(String key) => _prefs?.remove('$_prefix$key');
}
