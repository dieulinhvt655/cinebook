import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/movie_showtimes.dart';
import 'cubit/showtime_cubit.dart';

/// S07: 7-day strip, city filter, one expandable card per cinema with time chips grouped
/// by version ("2D Phụ đề"). Showtimes whose sales have closed are dimmed and disabled.
class ShowtimePickerPage extends StatelessWidget {
  const ShowtimePickerPage({super.key, required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ShowtimeCubit(sl(), movieId)..load(),
    child: const ShowtimePickerView(),
  );
}

class ShowtimePickerView extends StatelessWidget {
  const ShowtimePickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn suất chiếu')),
      body: BlocBuilder<ShowtimeCubit, ShowtimeState>(
        builder: (context, state) {
          final cubit = context.read<ShowtimeCubit>();
          return Column(
            children: [
              _DayStrip(
                days: state.days,
                selected: state.date,
                onSelect: cubit.selectDate,
              ),
              if (state.cities.length > 1 || state.city != null)
                _CityFilter(
                  cities: state.cities,
                  selected: state.city,
                  onChanged: cubit.selectCity,
                ),
              Expanded(child: _List(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.xs,
        ),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final d = days[i];
          final isSelected = d == selected;
          final parts = formatDayChip(d).split(', ');
          return Material(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              onTap: isSelected ? null : () => onSelect(d),
              child: SizedBox(
                width: 56,
                // Scales down rather than overflowing with large system text.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    children: [
                      Text(parts[0], style: const TextStyle(fontSize: 12)),
                      Text(
                        parts[1],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityFilter extends StatelessWidget {
  const _CityFilter({
    required this.cities,
    required this.selected,
    required this.onChanged,
  });

  final List<String> cities;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          DropdownButton<String?>(
            value: selected,
            underline: const SizedBox.shrink(),
            onChanged: onChanged,
            items: [
              const DropdownMenuItem(child: Text('Tất cả thành phố')),
              for (final c in cities)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final ShowtimeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShowtimeCubit>();
    if (state.failure case final f?) {
      return ErrorView(message: f.message, onRetry: cubit.load);
    }
    if (state.loading) {
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
    final cinemas = state.cinemas;
    if (cinemas.isEmpty) {
      final next = state.data?.nextAvailableDate;
      return EmptyView(
        icon: Icons.event_busy,
        message: 'Không có suất chiếu ngày này',
        actionLabel: next == null ? null : 'Xem ngày ${formatDayChip(next)}',
        onAction: next == null ? null : () => cubit.selectDate(next),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      itemCount: cinemas.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _CinemaCard(cinema: cinemas[i]),
    );
  }
}

class _CinemaCard extends StatelessWidget {
  const _CinemaCard({required this.cinema});

  final CinemaShowtimes cinema;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Text(cinema.name, style: text.titleSmall),
        subtitle: Text(
          cinema.address ?? cinema.city,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: version, value: slots)
              in cinema.byVersion.entries) ...[
            Text(version, style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final s in slots) _TimeChip(slot: s)],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.slot});

  final ShowtimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final time = formatTime(slot.startAt);
    return Semantics(
      label: slot.bookable ? 'Suất $time' : 'Suất $time, đã đóng bán',
      excludeSemantics: true,
      child: Opacity(
        opacity: slot.bookable ? 1 : 0.4,
        child: OutlinedButton(
          onPressed: slot.bookable
              ? () => unawaited(context.push(Routes.seatMap(slot.id)))
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time),
              Text(
                slot.auditorium,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
