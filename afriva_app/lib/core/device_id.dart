import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Random per-install id sent as `X-Device-Id`, so a guest viewer counts once
/// in unique viewers / daily active users. Contains nothing about the person.
class DeviceId {
  DeviceId._();

  static const _key = 'device_id';

  static Future<String> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && saved.length >= 8) return saved;
      final id = random();
      await prefs.setString(_key, id);
      return id;
    } catch (_) {
      return random();
    }
  }

  /// 32 url-safe characters.
  static String random([int length = 32]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
