import '../../../core/storage/app_preferences.dart';

/// S05 "Tìm gần đây": the last few searched titles, newest first. Saved on the device and
/// cleared when the user signs out.
class RecentSearches {
  RecentSearches([this._prefs]) : _items = [...?_prefs?.recentSearches];

  static const max = 5;

  final AppPreferences? _prefs;
  final List<String> _items;

  List<String> get items => List.unmodifiable(_items);

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _items
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_items.length > max) _items.removeLast();
    _save();
  }

  void remove(String query) {
    _items.remove(query);
    _save();
  }

  void clear() {
    _items.clear();
    _save();
  }

  void _save() => _prefs?.setRecentSearches(List.of(_items));
}
