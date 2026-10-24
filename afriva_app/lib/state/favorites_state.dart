import 'package:flutter/foundation.dart';

import '../models/drama.dart';
import '../services/me_service.dart';

/// Keeps the "My List" membership in sync across screens.
class FavoritesState extends ChangeNotifier {
  FavoritesState(this._service);
  final MeService _service;

  final Set<int> _ids = {};
  final Set<int> _removed = {};
  List<Drama> _items = [];
  bool _loaded = false;

  List<Drama> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  /// Locally-known membership wins; otherwise trust the API's `is_favorite`.
  bool contains(Drama d) =>
      !_removed.contains(d.id) && (_ids.contains(d.id) || (!_loaded && d.isFavorite));

  Future<void> load() async {
    _items = await _service.favorites();
    _removed.clear();
    _ids
      ..clear()
      ..addAll(_items.map((d) => d.id));
    _loaded = true;
    notifyListeners();
  }

  /// Optimistic toggle; reverts on failure (and rethrows).
  Future<bool> toggle(Drama d) async {
    final was = contains(d);
    _apply(d, !was);
    try {
      final result = await _service.toggleFavorite(d.id);
      if (result != null && result != !was) _apply(d, result);
      return result ?? !was;
    } catch (_) {
      _apply(d, was);
      rethrow;
    }
  }

  void clear() {
    _ids.clear();
    _removed.clear();
    _items = [];
    _loaded = false;
    notifyListeners();
  }

  void _apply(Drama d, bool fav) {
    if (fav) {
      _ids.add(d.id);
      _removed.remove(d.id);
      if (!_items.any((e) => e.id == d.id)) _items = [d.copyWith(isFavorite: true), ..._items];
    } else {
      _ids.remove(d.id);
      _removed.add(d.id);
      _items = _items.where((e) => e.id != d.id).toList();
    }
    notifyListeners();
  }
}
