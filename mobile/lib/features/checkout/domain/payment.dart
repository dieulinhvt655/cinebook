import 'package:equatable/equatable.dart';

import 'booking.dart';

enum PaymentResult { success, failed }

/// One payment attempt (mock gateway). [succeeded] means the booking is PAID and has tickets.
class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.status,
    required this.amount,
    required this.booking,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: (json['id'] as num).toInt(),
    status: json['status'] as String,
    amount: (json['amount'] as num).toInt(),
    booking: Booking.fromJson(json['booking'] as Map<String, dynamic>),
  );

  final int id;

  /// SUCCESS or FAILED.
  final String status;
  final int amount;
  final Booking booking;

  bool get succeeded => status == 'SUCCESS';

  @override
  List<Object?> get props => [id, status, amount, booking];
}
