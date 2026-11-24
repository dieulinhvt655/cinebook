import 'package:cinebook/features/seat_map/domain/seat_map.dart';
import 'package:cinebook/features/seat_map/domain/seat_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seat_map_fixtures.dart';

void main() {
  group('toggle', () {
    final map = seatMap(status: {'A1': 'SOLD', 'A2': 'HELD'});

    test('a couple seat selects and releases its pair', () {
      final on = SeatSelection.toggle(map, {}, map.seat('C2'));
      expect(on.selected, map.idsOf(['C1', 'C2']));

      final off = SeatSelection.toggle(map, on.selected, map.seat('C1'));
      expect(off.selected, isEmpty);
    });

    test('sold and held seats cannot be picked', () {
      expect(SeatSelection.toggle(map, {}, map.seat('A1')).selected, isEmpty);
      expect(SeatSelection.toggle(map, {}, map.seat('A2')).selected, isEmpty);
    });

    test('the 9th seat is refused and the selection stays as it was', () {
      final eight = map.idsOf(['A3', 'A5', 'B1', 'B2', 'B3', 'B4', 'B5', 'C5']);
      final r = SeatSelection.toggle(map, eight, map.seat('C1'));
      expect(r.limitReached, isTrue);
      expect(r.selected, eight);
    });

    test('a pair that would go past the limit is refused as a whole', () {
      final seven = map.idsOf(['A3', 'A5', 'B1', 'B2', 'B3', 'B4', 'B5']);
      final r = SeatSelection.toggle(map, seven, map.seat('C3'));
      expect(r.limitReached, isTrue);
      expect(r.selected, seven);
    });
  });

  group('findOrphan', () {
    Seat? orphan(SeatMap map, List<String> picked) =>
        SeatSelection.findOrphan(map, map.idsOf(picked));

    test('a free seat between a pick and a sold seat is an orphan', () {
      // Row B: B1 B2 B3 [B4 sold] B5
      final map = seatMap(status: {'B4': 'SOLD'});
      expect(orphan(map, ['B1', 'B2'])?.label, 'B3');
      expect(orphan(map, ['B2'])?.label, 'B1'); // stranded against the wall
      expect(orphan(map, ['B1', 'B2', 'B3']), isNull);
      expect(orphan(map, ['B5']), isNull);
    });

    test('a seat stranded against an aisle or wall counts too', () {
      final map = seatMap();
      // A3 sits next to the aisle (col 4): picking A2 strands it.
      expect(orphan(map, ['A1', 'A2'])?.label, 'A3');
      // A5 is alone between the aisle and the wall already: not caused by the user.
      expect(orphan(map, ['A1', 'A2', 'A3']), isNull);
    });

    test('gaps that were already there do not block', () {
      final map = seatMap(status: {'B1': 'SOLD', 'B3': 'SOLD'});
      // B2 was already boxed in by two sold seats.
      expect(orphan(map, ['B4', 'B5']), isNull);
    });

    test('couple seats are never orphans', () {
      final map = seatMap();
      // C1-C2 is left alone between the wall and the picked pair: allowed.
      expect(orphan(map, ['C3', 'C4', 'C5']), isNull);
      // C5 next to the wall is a normal seat, so it does count.
      expect(orphan(map, ['C3', 'C4'])?.label, 'C5');
    });
  });

  test('seatsOf keeps map order whatever the tap order', () {
    final map = seatMap();
    final ids = map.idsOf(['C5', 'A1', 'B3']);
    expect(SeatSelection.seatsOf(map, ids).map((s) => s.label), [
      'A1',
      'B3',
      'C5',
    ]);
  });
}
