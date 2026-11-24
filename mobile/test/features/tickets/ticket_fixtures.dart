const showJson = {
  'movieId': 3,
  'movieTitle': 'Phim Thử',
  'ageRating': 'T16',
  'posterUrl': null,
  'cinemaName': 'Rạp Một',
  'auditoriumName': 'Phòng 1',
  'startAt': '2026-11-22T12:00:00Z',
  'format': '2D',
  'subtitle': 'SUB',
};

Map<String, dynamic> ticketJson({int id = 7, String code = 'CBAB12CD'}) => {
  'id': id,
  'bookingCode': code,
  'show': showJson,
  'seats': ['F7', 'F8'],
  'paidAt': '2026-11-22T05:01:00Z',
};

Map<String, dynamic> ticketDetailJson({bool upcoming = true}) => {
  'id': 7,
  'bookingCode': 'CBAB12CD',
  'qrPayload': 'Q0JBQjEyQ0Q.c2lnbmF0dXJl',
  'upcoming': upcoming,
  'show': showJson,
  'seats': [
    {
      'label': 'F7',
      'type': 'VIP',
      'price': 105000,
      'ticketCode': 'TKAAAA222233',
      'status': 'VALID',
    },
    {
      'label': 'F8',
      'type': 'VIP',
      'price': 105000,
      'ticketCode': 'TKBBBB222233',
      'status': 'VALID',
    },
  ],
  'combos': [
    {'comboId': 1, 'name': 'Combo Solo', 'quantity': 1, 'unitPrice': 79000},
  ],
  'seatTotal': 210000,
  'comboTotal': 79000,
  'totalAmount': 289000,
  'paidAt': '2026-11-22T05:01:00Z',
};
