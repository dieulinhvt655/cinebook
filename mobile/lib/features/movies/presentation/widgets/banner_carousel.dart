import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/movie.dart';
import 'movie_image.dart';

/// 16:9 banners that move on by themselves every 5 seconds.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.movies, required this.onTap});

  final List<MovieSummary> movies;
  final ValueChanged<MovieSummary> onTap;

  static const interval = Duration(seconds: 5);

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(BannerCarousel.interval, (_) => _next());
  }

  void _next() {
    final count = widget.movies.length;
    if (count < 2 || !_controller.hasClients) return;
    unawaited(
      _controller.animateToPage(
        (_page + 1) % count,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _controller,
            itemCount: movies.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final m = movies[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: InkWell(
                    onTap: () => widget.onTap(m),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MovieImage(url: m.bannerUrl ?? m.posterUrl),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            color: Colors.black54,
                            child: Text(
                              m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (movies.length > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < movies.length; i++)
                Container(
                  width: i == _page ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
