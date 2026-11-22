import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/movie.dart';
import 'cubit/movie_detail_cubit.dart';
import 'widgets/movie_image.dart';

/// S06: banner with trailer button, poster, title, age badge, duration, genres, collapsible
/// description and a "Đặt vé" button fixed at the bottom.
class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({super.key, required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MovieDetailCubit(sl(), movieId)..load(),
    child: const MovieDetailView(),
  );
}

class MovieDetailView extends StatelessWidget {
  const MovieDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovieDetailCubit, MovieDetailState>(
      builder: (context, state) {
        final movie = state.movie;
        return Scaffold(
          appBar: AppBar(title: Text(movie?.title ?? '')),
          body: switch (state) {
            MovieDetailState(movie: final m?) => _Body(movie: m),
            MovieDetailState(failure: final f?) => ErrorView(
              message: f.message,
              onRetry: context.read<MovieDetailCubit>().load,
            ),
            _ => const _DetailSkeleton(),
          },
          bottomNavigationBar: movie == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    child: PrimaryButton(
                      label: 'Đặt vé',
                      onPressed: () =>
                          unawaited(context.push(Routes.showtimes(movie.id))),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.movie});

  final MovieDetail movie;

  Future<void> _openTrailer(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không mở được trailer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final trailer = movie.trailerUrl;
    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MovieImage(url: movie.bannerUrl ?? movie.posterUrl),
              if (trailer != null && trailer.isNotEmpty)
                Center(
                  child: IconButton.filled(
                    iconSize: 40,
                    tooltip: 'Xem trailer',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => unawaited(_openTrailer(context, trailer)),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    child: MovieImage(url: movie.posterUrl),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, style: text.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        AgeRatingBadge(movie.ageRating),
                        const SizedBox(width: AppSpacing.xs),
                        Text('${movie.durationMin} phút', style: secondary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (movie.genres.isNotEmpty)
                      Text(movie.genres.join(', '), style: secondary),
                    Text(
                      'Khởi chiếu ${formatDate(movie.releaseDate)}',
                      style: secondary,
                    ),
                    if (movie.language case final lang?)
                      Text('Ngôn ngữ: $lang', style: secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (movie.description case final d? when d.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: _Description(text: d),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Four lines, then "Xem thêm".
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = Theme.of(context).textTheme.bodyMedium;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final long = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (long)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Thu gọn' : 'Xem thêm'),
              ),
          ],
        );
      },
    );
  }
}

/// Banner and 3 lines of text.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox(radius: 0)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in [220.0, 160.0, 260.0]) ...[
                SkeletonBox(width: w, height: 16, radius: 4),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
