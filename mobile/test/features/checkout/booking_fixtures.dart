Map<String, dynamic> bookingJson({
  int id = 7,
  String status = 'HOLDING',
  String expiresAt = '2026-11-22T05:10:00Z',
  String serverTime = '2026-11-22T05:00:00Z',
}) => {
  'id': id,
  'bookingCode': 'CBAB12CD',
  'showtimeId': 42,
  'status': status,
  'seats': [
    {'seatId': 11, 'label': 'B1', 'type': 'VIP', 'price': 105000},
    {'seatId': 12, 'label': 'B2', 'type': 'VIP', 'price': 105000},
  ],
  'seatTotal': 210000,
  'comboTotal': 0,
  'totalAmount': 210000,
  'expiresAt': expiresAt,
  'serverTime': serverTime,
};
