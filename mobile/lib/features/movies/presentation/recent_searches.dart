/// S05 "Tìm gần đây": the last few searched titles, newest first. Kept in memory for the
/// app session only.
class RecentSearches {
  static const max = 5;

  final List<String> _items = [];

  List<String> get items => List.unmodifiable(_items);

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _items
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_items.length > max) _items.removeLast();
  }

  void remove(String query) => _items.remove(query);
}
