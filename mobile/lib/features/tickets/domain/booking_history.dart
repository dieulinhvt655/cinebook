import 'package:equatable/equatable.dart';

import '../../checkout/domain/booking.dart';

/// Where a booking ended up. An unknown value from a newer server reads as [other].
enum BookingStatus {
  holding,
  paid,
  expired,
  cancelled,
  other;

  static BookingStatus parse(String value) => switch (value) {
    'HOLDING' => holding,
    'PAID' => paid,
    'EXPIRED' => expired,
    'CANCELLED' => cancelled,
    _ => other,
  };
}

/// One row of "Lịch sử giao dịch" on S14. A [BookingStatus.paid] [id] opens the ticket (S13).
class BookingHistoryItem extends Equatable {
  const BookingHistoryItem({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.show,
    required this.seats,
    required this.totalAmount,
    required this.createdAt,
    this.paidAt,
  });

  factory BookingHistoryItem.fromJson(Map<String, dynamic> json) =>
      BookingHistoryItem(
        id: (json['id'] as num).toInt(),
        bookingCode: json['bookingCode'] as String,
        status: BookingStatus.parse(json['status'] as String),
        show: BookingShow.fromJson(json['show'] as Map<String, dynamic>),
        seats: [for (final s in json['seats'] as List<dynamic>) s as String],
        totalAmount: (json['totalAmount'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        paidAt: switch (json['paidAt']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
      );

  final int id;
  final String bookingCode;
  final BookingStatus status;
  final BookingShow show;

  /// Seat labels as chosen, also for a cancelled or expired booking.
  final List<String> seats;
  final int totalAmount;
  final DateTime createdAt;
  final DateTime? paidAt;

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    status,
    show,
    seats,
    totalAmount,
    createdAt,
    paidAt,
  ];
}
