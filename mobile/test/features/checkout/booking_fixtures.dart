Map<String, dynamic> bookingJson({
  int id = 7,
  String status = 'HOLDING',
  String expiresAt = '2026-11-22T05:10:00Z',
  String serverTime = '2026-11-22T05:00:00Z',
  List<Map<String, dynamic>> combos = const [],
  int comboTotal = 0,
}) => {
  'id': id,
  'bookingCode': 'CBAB12CD',
  'showtimeId': 42,
  'status': status,
  'show': {
    'movieId': 3,
    'movieTitle': 'Phim Thử',
    'ageRating': 'T16',
    'posterUrl': null,
    'cinemaName': 'Rạp Một',
    'auditoriumName': 'Phòng 1',
    'startAt': '2026-11-22T12:00:00Z',
    'format': '2D',
    'subtitle': 'SUB',
  },
  'combos': combos,
  'seats': [
    {'seatId': 11, 'label': 'B1', 'type': 'VIP', 'price': 105000},
    {'seatId': 12, 'label': 'B2', 'type': 'VIP', 'price': 105000},
  ],
  'seatTotal': 210000,
  'comboTotal': comboTotal,
  'totalAmount': 210000 + comboTotal,
  'expiresAt': expiresAt,
  'serverTime': serverTime,
};

const comboSolo = {
  'id': 1,
  'name': 'Combo Solo',
  'description': '1 bắp + 1 nước',
  'price': 79000,
  'imageUrl': null,
};

const comboFamily = {
  'id': 3,
  'name': 'Combo Family',
  'description': null,
  'price': 189000,
  'imageUrl': null,
};

Map<String, dynamic> paymentJson({
  String status = 'SUCCESS',
  String bookingStatus = 'PAID',
}) => {
  'id': 5,
  'bookingId': 7,
  'method': 'MOCK',
  'amount': 210000,
  'status': status,
  'createdAt': '2026-11-22T05:01:00Z',
  'booking': bookingJson(status: bookingStatus),
};
