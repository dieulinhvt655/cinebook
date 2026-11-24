import 'package:equatable/equatable.dart';

/// A combo on sale (S09).
class Combo extends Equatable {
  const Combo({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  factory Combo.fromJson(Map<String, dynamic> json) => Combo(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toInt(),
    imageUrl: json['imageUrl'] as String?,
  );

  /// Most of one combo per booking (backend rule).
  static const maxQuantity = 10;

  final int id;
  final String name;
  final String? description;
  final int price;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, description, price, imageUrl];
}
