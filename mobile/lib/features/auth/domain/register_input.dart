import 'package:equatable/equatable.dart';

/// S03 form data for `POST /auth/register`. Confirm-password and terms are checked on the form.
class RegisterInput extends Equatable {
  const RegisterInput({
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
    this.dateOfBirth,
  });

  final String email;
  final String password;
  final String fullName;
  final String? phone;
  final DateTime? dateOfBirth;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'fullName': fullName,
    if (phone != null) 'phone': phone,
    if (dateOfBirth case final d?)
      'dateOfBirth':
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}',
  };

  @override
  List<Object?> get props => [email, password, fullName, phone, dateOfBirth];
}
