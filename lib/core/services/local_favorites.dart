import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, login-free favorites store backed by [SharedPreferences].
///
/// Persists a set of vendor IDs on the device. The UI listens to this
/// notifier and re-renders whenever the set changes.
class LocalFavorites extends ChangeNotifier {
  LocalFavorites._();
  static final LocalFavorites instance = LocalFavorites._();

  static const _key = 'local_favorite_vendor_ids';

  final Set<int> _ids = <int>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<int> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  /// Loads the persisted set from disk. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? const <String>[];
    _ids
      ..clear()
      ..addAll(stored.map(int.tryParse).whereType<int>());
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(int vendorId) => _ids.contains(vendorId);

  Future<bool> toggle(int vendorId) async {
    await load();
    final added = _ids.contains(vendorId) ? false : true;
    if (added) {
      _ids.add(vendorId);
    } else {
      _ids.remove(vendorId);
    }
    await _persist();
    notifyListeners();
    return added;
  }

  Future<void> add(int vendorId) async {
    await load();
    if (_ids.add(vendorId)) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> remove(int vendorId) async {
    await load();
    if (_ids.remove(vendorId)) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _ids.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.map((e) => e.toString()).toList());
  }
}
