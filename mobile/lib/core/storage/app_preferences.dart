import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-secret settings kept on the device: the chosen city and recent searches.
/// Tokens stay in [TokenStorage] (secure storage).
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _city = 'city';
  static const _recentSearches = 'recent_searches';

  String? get city => _prefs.getString(_city);

  Future<void> setCity(String? city) =>
      city == null ? _prefs.remove(_city) : _prefs.setString(_city, city);

  List<String> get recentSearches =>
      _prefs.getStringList(_recentSearches) ?? const [];

  Future<void> setRecentSearches(List<String> items) =>
      _prefs.setStringList(_recentSearches, items);
}
