import 'package:equatable/equatable.dart';

class BookedSeat extends Equatable {
  const BookedSeat({
    required this.seatId,
    required this.label,
    required this.type,
    required this.price,
  });

  factory BookedSeat.fromJson(Map<String, dynamic> json) => BookedSeat(
    seatId: (json['seatId'] as num).toInt(),
    label: json['label'] as String,
    type: json['type'] as String,
    price: (json['price'] as num).toInt(),
  );

  final int seatId;

  /// Row + column, e.g. "F7".
  final String label;
  final String type;

  /// Fixed when the seat was held.
  final int price;

  @override
  List<Object?> get props => [seatId, label, type, price];
}

/// A booking as its owner sees it (backend `BookingView`). A hold past [expiresAt] comes
/// back as EXPIRED. The countdown uses [expiresAt] with the server clock, never the phone's.
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.showtimeId,
    required this.status,
    required this.seats,
    required this.seatTotal,
    required this.comboTotal,
    required this.totalAmount,
    required this.expiresAt,
    required this.serverTime,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: (json['id'] as num).toInt(),
    bookingCode: json['bookingCode'] as String,
    showtimeId: (json['showtimeId'] as num).toInt(),
    status: json['status'] as String,
    seats: [
      for (final s in json['seats'] as List<dynamic>)
        BookedSeat.fromJson(s as Map<String, dynamic>),
    ],
    seatTotal: (json['seatTotal'] as num).toInt(),
    comboTotal: (json['comboTotal'] as num).toInt(),
    totalAmount: (json['totalAmount'] as num).toInt(),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    serverTime: DateTime.parse(json['serverTime'] as String),
  );

  static const holding = 'HOLDING';

  final int id;
  final String bookingCode;
  final int showtimeId;

  /// HOLDING, PAID, EXPIRED or CANCELLED.
  final String status;
  final List<BookedSeat> seats;
  final int seatTotal;
  final int comboTotal;
  final int totalAmount;
  final DateTime expiresAt;
  final DateTime serverTime;

  bool get isHolding => status == holding;

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    showtimeId,
    status,
    seats,
    seatTotal,
    comboTotal,
    totalAmount,
    expiresAt,
    serverTime,
  ];
}
