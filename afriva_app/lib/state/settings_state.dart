import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';

/// Lightweight user preferences persisted with shared_preferences.
class SettingsState extends ChangeNotifier {
  static const _kAutoplay = 'autoplay_next';
  static const _kLanguage = 'language';
  static const _kRecent = 'recent_searches';

  SharedPreferences? _prefs;

  bool _autoplayNext = true;
  String _language = kDefaultLanguage;
  List<String> _recentSearches = [];

  bool get autoplayNext => _autoplayNext;
  String get language => _language;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _autoplayNext = _prefs!.getBool(_kAutoplay) ?? true;
      _language = _prefs!.getString(_kLanguage) ?? kDefaultLanguage;
      I18n.language = _language;
      _recentSearches = _prefs!.getStringList(_kRecent) ?? [];
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

  void setLanguage(String v) {
    _language = v;
    I18n.language = v;
    _prefs?.setString(_kLanguage, v);
    notifyListeners();
  }

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
