import 'package:cinebook/features/seat_map/domain/seat_map.dart';

/// Room used across the seat map tests (5 columns):
///
///   A: A1  A2  A3  ··  A5      (col 4 is an aisle)
///   B: B1  B2  B3  B4  B5      (VIP)
///   C: [C1-C2] [C3-C4] C5      (couple pairs, C5 standard)
Map<String, dynamic> seatMapJson({
  Map<String, String> status = const {},
  bool bookable = true,
  int maxSeats = 8,
  int? availableCount,
}) {
  var id = 0;
  final ids = <String, int>{};
  Map<String, dynamic> seat(String row, int col, String type, int price) {
    final label = '$row$col';
    ids[label] = ++id;
    return {
      'id': id,
      'row': row,
      'col': col,
      'type': type,
      'price': price,
      'status': status[label] ?? 'AVAILABLE',
      'pairSeatId': null,
    };
  }

  final a = [
    for (final c in [1, 2, 3, 5]) seat('A', c, 'STANDARD', 90000),
  ];
  final b = [for (var c = 1; c <= 5; c++) seat('B', c, 'VIP', 105000)];
  final c = [
    for (var c = 1; c <= 4; c++) seat('C', c, 'COUPLE', 120000),
    seat('C', 5, 'STANDARD', 90000),
  ];
  for (final (x, y) in [(0, 1), (2, 3)]) {
    c[x]['pairSeatId'] = c[y]['id'];
    c[y]['pairSeatId'] = c[x]['id'];
  }
  final all = [...a, ...b, ...c];
  return {
    'showtimeId': 42,
    'startAt': '2026-11-22T12:30:00Z',
    'endAt': '2026-11-22T14:30:00Z',
    'format': '2D',
    'subtitle': 'SUB',
    'basePrice': 90000,
    'bookable': bookable,
    'movie': {
      'id': 7,
      'title': 'Phim Thử',
      'ageRating': 'T13',
      'durationMin': 120,
      'posterUrl': null,
    },
    'venue': {
      'cinemaId': 1,
      'cinemaName': 'CineBook Tràng Tiền',
      'auditoriumId': 3,
      'auditoriumName': 'Phòng 1',
      'rowCount': 3,
      'colCount': 5,
    },
    'seatTypes': [
      {
        'code': 'STANDARD',
        'name': 'Thường',
        'surcharge': 0,
        'seatsPerUnit': 1,
        'price': 90000,
      },
      {
        'code': 'VIP',
        'name': 'VIP',
        'surcharge': 15000,
        'seatsPerUnit': 1,
        'price': 105000,
      },
      {
        'code': 'COUPLE',
        'name': 'Ghế đôi',
        'surcharge': 30000,
        'seatsPerUnit': 2,
        'price': 120000,
      },
    ],
    'rows': [
      {'label': 'A', 'seats': a},
      {'label': 'B', 'seats': b},
      {'label': 'C', 'seats': c},
    ],
    'availableCount':
        availableCount ?? all.where((s) => s['status'] == 'AVAILABLE').length,
    'maxSeats': maxSeats,
    'serverTime': '2026-11-22T05:00:00Z',
  };
}

SeatMap seatMap({
  Map<String, String> status = const {},
  bool bookable = true,
  int maxSeats = 8,
  int? availableCount,
}) => SeatMap.fromJson(
  seatMapJson(
    status: status,
    bookable: bookable,
    maxSeats: maxSeats,
    availableCount: availableCount,
  ),
);

extension SeatLookup on SeatMap {
  Seat seat(String label) => seats.firstWhere((s) => s.label == label);

  Set<int> idsOf(List<String> labels) => {for (final l in labels) seat(l).id};
}
