import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../movies/presentation/widgets/movie_image.dart';
import '../domain/cinema.dart';
import 'cubit/cinema_schedule_cubit.dart';
import 'widgets/day_strip.dart';
import 'widgets/time_chip.dart';

/// One cinema's showtimes by day ("Rạp" tab), grouped by movie. Same rules as S07: closed
/// sales are dimmed, an empty day offers the next date with showtimes.
class CinemaSchedulePage extends StatelessWidget {
  const CinemaSchedulePage({super.key, required this.cinemaId});

  final int cinemaId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CinemaScheduleCubit(sl(), cinemaId)..load(),
    child: const CinemaScheduleView(),
  );
}

class CinemaScheduleView extends StatelessWidget {
  const CinemaScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CinemaScheduleCubit, CinemaScheduleState>(
      builder: (context, state) {
        final cubit = context.read<CinemaScheduleCubit>();
        final cinema = state.data?.cinema;
        return Scaffold(
          appBar: AppBar(
            title: Text(cinema?.name ?? 'Lịch chiếu'),
            bottom: cinema == null
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(24),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        cinema.address,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
          ),
          body: Column(
            children: [
              DayStrip(
                days: state.days,
                selected: state.date,
                onSelect: cubit.selectDate,
              ),
              Expanded(child: _List(state: state)),
            ],
          ),
        );
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final CinemaScheduleState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CinemaScheduleCubit>();
    if (state.failure case final f?) {
      return ErrorView(message: f.message, onRetry: cubit.load);
    }
    final data = state.data;
    if (data == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 120),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }
    if (data.movies.isEmpty) {
      final next = data.nextAvailableDate;
      return EmptyView(
        icon: Icons.event_busy,
        message: 'Không có suất chiếu ngày này',
        actionLabel: next == null ? null : 'Xem ngày ${formatDayChip(next)}',
        onAction: next == null ? null : () => cubit.selectDate(next),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      itemCount: data.movies.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _MovieCard(movie: data.movies[i]),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.movie});

  final MovieSlots movie;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => unawaited(context.push(Routes.movie(movie.movieId))),
              child: SizedBox(
                width: 64,
                height: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: MovieImage(url: movie.posterUrl),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      AgeRatingBadge(movie.ageRating),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${movie.durationMin} phút',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final s in movie.showtimes) TimeChip(slot: s),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
