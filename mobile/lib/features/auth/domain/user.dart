import 'package:equatable/equatable.dart';

/// The signed-in account, as returned by the backend `UserResponse`.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.dateOfBirth,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] as num).toInt(),
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String?,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.parse(json['dateOfBirth'] as String),
    role: json['role'] as String,
  );

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final DateTime? dateOfBirth;

  /// `CUSTOMER` or `ADMIN` (backend `Role`).
  final String role;

  @override
  List<Object?> get props => [id, email, fullName, phone, dateOfBirth, role];
}
