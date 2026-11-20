import 'package:material_ui/material_ui.dart';

/// Dark-theme colour tokens (design doc 4.5).
abstract final class AppColors {
  static const primary = Color(0xFFE5383B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const background = Color(0xFF0F0F14);
  static const surface = Color(0xFF1A1A22);
  static const surfaceVariant = Color(0xFF26262F);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const outline = Color(0xFF3F3F46);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Seats: always paired with a non-colour cue (×, clock icon, check) for colour-blind users.
  static const seatVip = Color(0xFFF5B700);
  static const seatCouple = Color(0xFFEC4899);
  static const seatSold = Color(0xFF3F3F46);
  static const seatHeld = Color(0xFF71717A);

  // Age ratings.
  static const ratingP = Color(0xFF22C55E);
  static const ratingK = Color(0xFF3B82F6);
  static const ratingT13 = Color(0xFFEAB308);
  static const ratingT16 = Color(0xFFF97316);
  static const ratingT18 = Color(0xFFEF4444);
}
