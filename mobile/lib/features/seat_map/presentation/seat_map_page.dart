import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/seat_map.dart';
import 'cubit/seat_map_cubit.dart';
import 'widgets/seat_tile.dart';

/// S08: header, screen curve, zoomable seat grid with row labels on both sides, legend
/// and a sticky bar with the picked seats, the total and "Tiếp tục".
class SeatMapPage extends StatelessWidget {
  const SeatMapPage({super.key, required this.showtimeId});

  final int showtimeId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SeatMapCubit(sl(), sl(), showtimeId)..load(),
    child: const SeatMapView(),
  );
}

class SeatMapView extends StatelessWidget {
  const SeatMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeatMapCubit, SeatMapState>(
      listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.notice!.message))),
      builder: (context, state) {
        final cubit = context.read<SeatMapCubit>();
        final map = state.map;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              map?.movieTitle ?? 'Chọn ghế',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (map != null)
                IconButton(
                  tooltip: 'Tải lại sơ đồ ghế',
                  onPressed: state.loading ? null : cubit.load,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          body: switch ((map, state.failure)) {
            (null, final f?) => ErrorView(
              message: f.message,
              onRetry: cubit.load,
            ),
            (null, _) => const _GridSkeleton(),
            (final m?, _) => _Body(map: m, state: state),
          },
          bottomNavigationBar: map == null || map.soldOut || !map.bookable
              ? null
              : _SummaryBar(
                  state: state,
                  onContinue: () => unawaited(_continue(context)),
                ),
        );
      },
    );
  }

  /// Holds the seats and opens S09. Coming back (hold cancelled or expired) reloads the
  /// map, so the seats just released show as free again.
  Future<void> _continue(BuildContext context) async {
    final cubit = context.read<SeatMapCubit>();
    final booking = await cubit.hold();
    if (booking == null || !context.mounted) return;
    await context.push(Routes.combos(booking.id));
    if (!cubit.isClosed) await cubit.load();
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.map, required this.state});

  final SeatMap map;
  final SeatMapState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.xs,
            AppSpacing.pagePadding,
            0,
          ),
          child: Row(
            children: [
              AgeRatingBadge(map.ageRating),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${map.cinemaName} · ${map.auditoriumName}\n'
                  '${formatTime(map.startAt)}, ${formatDayChip(map.startAt)}'
                  ' · ${map.versionLabel}',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (map.soldOut)
          _Banner(
            message: 'Đã hết vé',
            actionLabel: 'Chọn suất khác',
            onAction: () => context.pop(),
          )
        else if (!map.bookable)
          _Banner(
            message: 'Suất chiếu đã đóng bán online',
            actionLabel: 'Chọn suất khác',
            onAction: () => context.pop(),
          ),
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: AppSpacing.sm),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ScreenCurve(),
        ),
        Flexible(
          child: _SeatGrid(map: map, selected: state.selected),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: SeatLegend(types: map.seatTypes),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message)),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// Seat size follows the screen width (design doc 4.4): (width − margins − labels) / columns,
/// never below 24 dp. Wider rooms scroll and zoom (1×–2.5×) instead of shrinking further.
class _SeatGrid extends StatelessWidget {
  const _SeatGrid({required this.map, required this.selected});

  final SeatMap map;
  final Set<int> selected;

  static const _labelWidth = 20.0;
  static const _maxSeat = 40.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeatMapCubit>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable =
            constraints.maxWidth - 2 * AppSpacing.pagePadding - 2 * _labelWidth;
        final size = (usable / map.colCount).clamp(
          AppSpacing.minSeat,
          _maxSeat,
        );
        final gridWidth = size * map.colCount + 2 * _labelWidth;
        final width = math.max(constraints.maxWidth, gridWidth);
        final height = size * map.rows.length + 2 * AppSpacing.md;
        // As tall as the rows (so the legend follows right below), capped by the space left.
        return SizedBox(
          height: math.min(height, constraints.maxHeight),
          child: InteractiveViewer(
            constrained: false,
            minScale: 1,
            maxScale: 2.5,
            child: SizedBox(
              width: width,
              height: height,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in map.rows)
                      _Row(
                        row: row,
                        colCount: map.colCount,
                        size: size,
                        selected: selected,
                        onTap: map.bookable ? cubit.toggle : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.colCount,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final SeatRow row;
  final int colCount;
  final double size;
  final Set<int> selected;
  final ValueChanged<Seat>? onTap;

  @override
  Widget build(BuildContext context) {
    final byCol = {for (final s in row.seats) s.col: s};
    final label = SizedBox(
      width: _SeatGrid._labelWidth,
      child: Text(
        row.label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
    final cells = <Widget>[];
    for (var col = 1; col <= colCount; col++) {
      final seat = byCol[col];
      if (seat == null) {
        cells.add(SizedBox(width: size, height: size)); // aisle
        continue;
      }
      // A couple pair is drawn as one double-width seat.
      final next = byCol[col + 1];
      final pair = seat.pairSeatId != null && next?.id == seat.pairSeatId
          ? [seat, next!]
          : [seat];
      cells.add(
        SeatTile(
          seats: pair,
          selected: selected.contains(seat.id),
          size: size,
          onTap: onTap == null || !seat.isAvailable ? null : () => onTap!(seat),
        ),
      );
      col += pair.length - 1;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [label, ...cells, label],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.state, required this.onContinue});

  final SeatMapState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final seats = state.selectedSeats;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seats.isEmpty
                          ? 'Chưa chọn ghế'
                          : 'Ghế: ${seats.map((s) => s.label).join(', ')}',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatVnd(state.total),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 140,
                height: AppSpacing.buttonHeight,
                child: PrimaryButton(
                  label: 'Tiếp tục',
                  loading: state.holding,
                  onPressed: state.canContinue ? onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        children: [
          const SkeletonBox(height: 40),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 8; i++) ...[
            const SkeletonBox(height: 24),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
