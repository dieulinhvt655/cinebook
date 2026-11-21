import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';

/// Poster or banner from the API. Movies without artwork (or a broken link) get a plain
/// tile with a film icon, so the layout never collapses.
class MovieImage extends StatelessWidget {
  const MovieImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const _NoImage();
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceVariant),
      errorWidget: (_, _, _) => const _NoImage(),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surfaceVariant,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        size: 40,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
