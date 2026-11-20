import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Type scale (design doc 4.5). Font: Be Vietnam Pro, bundled in assets/fonts.
abstract final class AppTextStyles {
  static const fontFamily = 'BeVietnamPro';

  static const textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );

  /// Totals: 20/700 with tabular figures so digits do not jump while counting.
  static const price = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Booking code: 18/600 monospace.
  static const code = TextStyle(
    fontFamily: 'monospace',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
  );
}
