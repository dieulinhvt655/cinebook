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

class BookedCombo extends Equatable {
  const BookedCombo({
    required this.comboId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  factory BookedCombo.fromJson(Map<String, dynamic> json) => BookedCombo(
    comboId: (json['comboId'] as num).toInt(),
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toInt(),
    unitPrice: (json['unitPrice'] as num).toInt(),
  );

  final int comboId;
  final String name;
  final int quantity;

  /// Fixed when the combo was picked.
  final int unitPrice;

  @override
  List<Object?> get props => [comboId, name, quantity, unitPrice];
}

/// The showtime of a booking, as S10 and the ticket show it.
class BookingShow extends Equatable {
  const BookingShow({
    required this.movieId,
    required this.movieTitle,
    required this.ageRating,
    required this.posterUrl,
    required this.cinemaName,
    required this.auditoriumName,
    required this.startAt,
    required this.format,
    required this.subtitle,
  });

  factory BookingShow.fromJson(Map<String, dynamic> json) => BookingShow(
    movieId: (json['movieId'] as num).toInt(),
    movieTitle: json['movieTitle'] as String,
    ageRating: json['ageRating'] as String,
    posterUrl: json['posterUrl'] as String?,
    cinemaName: json['cinemaName'] as String,
    auditoriumName: json['auditoriumName'] as String,
    startAt: DateTime.parse(json['startAt'] as String),
    format: json['format'] as String,
    subtitle: json['subtitle'] as String,
  );

  final int movieId;
  final String movieTitle;
  final String ageRating;
  final String? posterUrl;
  final String cinemaName;
  final String auditoriumName;
  final DateTime startAt;
  final String format;
  final String subtitle;

  @override
  List<Object?> get props => [
    movieId,
    movieTitle,
    ageRating,
    posterUrl,
    cinemaName,
    auditoriumName,
    startAt,
    format,
    subtitle,
  ];
}

/// A booking as its owner sees it (backend `BookingView`). A hold past [expiresAt] comes
/// back as EXPIRED. The countdown uses [expiresAt] with the server clock, never the phone's.
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.showtimeId,
    required this.status,
    required this.show,
    required this.seats,
    this.combos = const [],
    required this.seatTotal,
    required this.comboTotal,
    required this.totalAmount,
    required this.expiresAt,
    this.paidAt,
    required this.serverTime,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: (json['id'] as num).toInt(),
    bookingCode: json['bookingCode'] as String,
    showtimeId: (json['showtimeId'] as num).toInt(),
    status: json['status'] as String,
    show: BookingShow.fromJson(json['show'] as Map<String, dynamic>),
    combos: [
      for (final c in json['combos'] as List<dynamic>? ?? const [])
        BookedCombo.fromJson(c as Map<String, dynamic>),
    ],
    seats: [
      for (final s in json['seats'] as List<dynamic>)
        BookedSeat.fromJson(s as Map<String, dynamic>),
    ],
    seatTotal: (json['seatTotal'] as num).toInt(),
    comboTotal: (json['comboTotal'] as num).toInt(),
    totalAmount: (json['totalAmount'] as num).toInt(),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    paidAt: json['paidAt'] == null
        ? null
        : DateTime.parse(json['paidAt'] as String),
    serverTime: DateTime.parse(json['serverTime'] as String),
  );

  static const holding = 'HOLDING';

  final int id;
  final String bookingCode;
  final int showtimeId;

  /// HOLDING, PAID, EXPIRED or CANCELLED.
  final String status;
  final BookingShow show;
  final List<BookedSeat> seats;
  final List<BookedCombo> combos;
  final int seatTotal;
  final int comboTotal;
  final int totalAmount;
  final DateTime expiresAt;
  final DateTime? paidAt;
  final DateTime serverTime;

  bool get isHolding => status == holding;

  /// Combo id → quantity, as S09 edits it.
  Map<int, int> get comboQuantities => {
    for (final c in combos) c.comboId: c.quantity,
  };

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    showtimeId,
    status,
    show,
    seats,
    combos,
    seatTotal,
    comboTotal,
    totalAmount,
    expiresAt,
    paidAt,
    serverTime,
  ];
}
