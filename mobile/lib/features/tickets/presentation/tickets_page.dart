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
import '../domain/ticket.dart';
import 'cubit/tickets_cubit.dart';

/// S12: "Sắp tới" / "Đã xem" tabs with ticket cards (poster, title, cinema, time, seats).
class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = sl<TicketsCubit>();
    if (cubit.state.visible == null && !cubit.state.loading) {
      unawaited(cubit.load());
    }
    return BlocProvider.value(value: cubit, child: const TicketsView());
  }
}

class TicketsView extends StatelessWidget {
  const TicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vé của tôi')),
      body: BlocBuilder<TicketsCubit, TicketsState>(
        builder: (context, state) {
          final cubit = context.read<TicketsCubit>();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: SegmentedButton<TicketScope>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TicketScope.upcoming,
                      label: Text('Sắp tới'),
                    ),
                    ButtonSegment(
                      value: TicketScope.past,
                      label: Text('Đã xem'),
                    ),
                  ],
                  selected: {state.tab},
                  onSelectionChanged: (s) =>
                      unawaited(cubit.selectTab(s.first)),
                ),
              ),
              Expanded(child: _List(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final TicketsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TicketsCubit>();
    final list = state.visible;
    if (list == null) {
      if (state.failure case final f?) {
        return ErrorView(message: f.message, onRetry: cubit.load);
      }
      return const _Skeleton();
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: AppSpacing.xl),
                EmptyView(
                  icon: Icons.confirmation_number_outlined,
                  message: state.tab == TicketScope.upcoming
                      ? 'Bạn chưa có vé nào'
                      : 'Chưa có vé đã xem',
                  actionLabel: state.tab == TicketScope.upcoming
                      ? 'Đặt vé ngay'
                      : null,
                  onAction: () => context.go(Routes.home),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                0,
                AppSpacing.pagePadding,
                AppSpacing.lg,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => TicketCard(
                ticket: list[i],
                onTap: () => unawaited(context.push(Routes.ticket(list[i].id))),
              ),
            ),
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.onTap});

  final TicketSummary ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final show = ticket.show;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: MovieImage(url: show.posterUrl),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AgeRatingBadge(show.ageRating),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            show.movieTitle,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      show.cinemaName,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${formatTime(show.startAt)}, '
                      '${formatDayChip(show.startAt)} · ${show.format}',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Ghế: ${ticket.seats.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three ticket cards.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(height: 106),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
