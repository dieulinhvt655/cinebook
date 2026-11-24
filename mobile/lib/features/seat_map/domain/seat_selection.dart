import 'seat_map.dart';

/// Outcome of tapping a seat.
class ToggleResult {
  const ToggleResult(this.selected, {this.limitReached = false});

  final Set<int> selected;

  /// The tap was refused because it would exceed [SeatMap.maxSeats].
  final bool limitReached;
}

/// Client-side seat rules of F4 (design doc 1.3, items 4, 6 and 7). The server checks them
/// again when the seats are held (F5).
abstract final class SeatSelection {
  /// Couple seats are selected and released as a pair. Seats that are not available are
  /// ignored.
  static ToggleResult toggle(SeatMap map, Set<int> selected, Seat seat) {
    if (!seat.isAvailable) return ToggleResult(selected);
    final unit = <int>{seat.id};
    final pair = seat.pairSeatId == null
        ? null
        : map.seatById(seat.pairSeatId!);
    if (pair != null && pair.isAvailable) unit.add(pair.id);

    if (selected.contains(seat.id)) {
      return ToggleResult(selected.difference(unit));
    }
    final next = selected.union(unit);
    if (next.length > map.maxSeats) {
      return ToggleResult(selected, limitReached: true);
    }
    return ToggleResult(next);
  }

  /// The first single free seat the selection would strand: boxed in on both sides by a
  /// selected, sold or held seat, an aisle or the wall, with at least one side selected by
  /// this user (gaps that were already there do not count). Couple seats are sold in pairs,
  /// so they are never orphans.
  static Seat? findOrphan(SeatMap map, Set<int> selected) {
    for (final row in map.rows) {
      final byCol = {for (final s in row.seats) s.col: s};
      bool isSelected(Seat? s) => s != null && selected.contains(s.id);
      bool blocked(Seat? s) => s == null || !s.isAvailable || isSelected(s);

      for (final seat in row.seats) {
        if (seat.kind == SeatKind.couple ||
            !seat.isAvailable ||
            isSelected(seat)) {
          continue;
        }
        final left = byCol[seat.col - 1];
        final right = byCol[seat.col + 1];
        if (blocked(left) &&
            blocked(right) &&
            (isSelected(left) || isSelected(right))) {
          return seat;
        }
      }
    }
    return null;
  }

  /// Selected seats in map order (row, then column).
  static List<Seat> seatsOf(SeatMap map, Set<int> selected) =>
      map.seats.where((s) => selected.contains(s.id)).toList();
}
