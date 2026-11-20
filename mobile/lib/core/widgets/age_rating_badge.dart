import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';

/// Vietnamese film classification: P, K, T13, T16, T18.
class AgeRatingBadge extends StatelessWidget {
  const AgeRatingBadge(this.rating, {super.key});

  final String rating;

  static Color colorOf(String rating) => switch (rating) {
    'P' => AppColors.ratingP,
    'K' => AppColors.ratingK,
    'T13' => AppColors.ratingT13,
    'T16' => AppColors.ratingT16,
    _ => AppColors.ratingT18,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorOf(rating),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
