import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Lightweight user preferences persisted with shared_preferences.
class SettingsState extends ChangeNotifier {
  static const _kAutoplay = 'autoplay_next';
  static const _kLanguage = 'language';
  static const _kRecent = 'recent_searches';
  static const _kTheme = 'theme_mode';
  static const _kQuality = 'video_quality';

  SharedPreferences? _prefs;

  bool _autoplayNext = true;
  String _languageCode = 'en';
  List<String> _recentSearches = [];
  ThemeMode _themeMode = ThemeMode.dark;
  int _videoQuality = 0;

  bool get autoplayNext => _autoplayNext;
  /// `en` or `sw`.
  String get languageCode => _languageCode;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Dark by default; Light and System are opt-in.
  ThemeMode get themeMode => _themeMode;

  /// Preferred rendition height (720 = 720p); 0 means Auto.
  int get videoQuality => _videoQuality;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _autoplayNext = _prefs!.getBool(_kAutoplay) ?? true;
      final stored = _prefs!.getString(_kLanguage);
      _languageCode = _normalize(stored);
      if (stored != null && stored != _languageCode) _prefs!.setString(_kLanguage, _languageCode);
      L10n.setCode(_languageCode);
      _recentSearches = _prefs!.getStringList(_kRecent) ?? [];
      _videoQuality = _prefs!.getInt(_kQuality) ?? 0;
      _themeMode = ThemeMode.values.asNameMap()[_prefs!.getString(_kTheme)] ?? ThemeMode.dark;
      notifyListeners();
    } catch (_) {
      // Preferences unavailable, defaults are fine.
    }
  }

  void setAutoplayNext(bool v) {
    _autoplayNext = v;
    _prefs?.setBool(_kAutoplay, v);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _prefs?.setString(_kTheme, mode.name);
    notifyListeners();
  }

  void setVideoQuality(int height) {
    final q = height < 0 ? 0 : height;
    if (q == _videoQuality) return;
    _videoQuality = q;
    _prefs?.setInt(_kQuality, q);
    notifyListeners();
  }

  void setLanguage(String code) {
    final c = _normalize(code);
    if (c == _languageCode) return;
    _languageCode = c;
    L10n.setCode(c);
    _prefs?.setString(_kLanguage, c);
    notifyListeners();
  }

  /// Accepts a code or a legacy stored name ('English' / 'Kiswahili').
  static String _normalize(String? v) => switch (v?.trim().toLowerCase()) {
        'sw' || 'kiswahili' || 'swahili' => 'sw',
        _ => 'en',
      };

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    _recentSearches = [t, ..._recentSearches.where((e) => e.toLowerCase() != t.toLowerCase())]
        .take(10)
        .toList();
    _prefs?.setStringList(_kRecent, _recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches = [];
    _prefs?.remove(_kRecent);
    notifyListeners();
  }
}
