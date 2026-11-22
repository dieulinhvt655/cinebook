import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/age_rating_badge.dart';
import '../../domain/movie.dart';
import 'movie_image.dart';

/// Home grid cell: poster (about 2:3) with the age badge top-left, title on two lines and, for
/// coming-soon movies, the release date.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.showReleaseDate = false,
  });

  final MovieSummary movie;
  final VoidCallback onTap;
  final bool showReleaseDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Takes what the text leaves, so long titles never overflow the grid cell.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MovieImage(url: movie.posterUrl),
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: AgeRatingBadge(movie.ageRating),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall,
          ),
          if (showReleaseDate)
            Text(
              'Khởi chiếu ${formatDate(movie.releaseDate)}',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
