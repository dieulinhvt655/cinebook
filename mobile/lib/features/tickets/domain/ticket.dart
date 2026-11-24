import 'package:equatable/equatable.dart';

import '../../checkout/domain/booking.dart';

enum TicketScope { upcoming, past }

/// A card on S12: one paid booking. [id] is the booking id.
class TicketSummary extends Equatable {
  const TicketSummary({
    required this.id,
    required this.bookingCode,
    required this.show,
    required this.seats,
    required this.paidAt,
  });

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
    id: (json['id'] as num).toInt(),
    bookingCode: json['bookingCode'] as String,
    show: BookingShow.fromJson(json['show'] as Map<String, dynamic>),
    seats: [for (final s in json['seats'] as List<dynamic>) s as String],
    paidAt: DateTime.parse(json['paidAt'] as String),
  );

  final int id;
  final String bookingCode;
  final BookingShow show;

  /// Seat labels, e.g. ["F7", "F8"].
  final List<String> seats;
  final DateTime paidAt;

  @override
  List<Object?> get props => [id, bookingCode, show, seats, paidAt];
}

class SeatTicket extends Equatable {
  const SeatTicket({
    required this.label,
    required this.type,
    required this.price,
    required this.ticketCode,
    required this.status,
  });

  factory SeatTicket.fromJson(Map<String, dynamic> json) => SeatTicket(
    label: json['label'] as String,
    type: json['type'] as String,
    price: (json['price'] as num).toInt(),
    ticketCode: json['ticketCode'] as String,
    status: json['status'] as String,
  );

  final String label;
  final String type;
  final int price;
  final String ticketCode;

  /// VALID, USED or VOID.
  final String status;

  @override
  List<Object?> get props => [label, type, price, ticketCode, status];
}

/// S13: the ticket stub. [qrPayload] is signed by the server; the app only draws it.
class TicketDetail extends Equatable {
  const TicketDetail({
    required this.id,
    required this.bookingCode,
    required this.qrPayload,
    required this.upcoming,
    required this.show,
    required this.seats,
    required this.combos,
    required this.totalAmount,
    required this.paidAt,
  });

  factory TicketDetail.fromJson(Map<String, dynamic> json) => TicketDetail(
    id: (json['id'] as num).toInt(),
    bookingCode: json['bookingCode'] as String,
    qrPayload: json['qrPayload'] as String,
    upcoming: json['upcoming'] as bool,
    show: BookingShow.fromJson(json['show'] as Map<String, dynamic>),
    seats: [
      for (final s in json['seats'] as List<dynamic>)
        SeatTicket.fromJson(s as Map<String, dynamic>),
    ],
    combos: [
      for (final c in json['combos'] as List<dynamic>)
        BookedCombo.fromJson(c as Map<String, dynamic>),
    ],
    totalAmount: (json['totalAmount'] as num).toInt(),
    paidAt: DateTime.parse(json['paidAt'] as String),
  );

  final int id;
  final String bookingCode;
  final String qrPayload;

  /// False once the showtime has ended.
  final bool upcoming;
  final BookingShow show;
  final List<SeatTicket> seats;
  final List<BookedCombo> combos;
  final int totalAmount;
  final DateTime paidAt;

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    qrPayload,
    upcoming,
    show,
    seats,
    combos,
    totalAmount,
    paidAt,
  ];
}
