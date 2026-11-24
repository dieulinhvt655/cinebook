import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/movie_showtimes.dart';

/// One showtime: start time and free seats; dimmed and disabled once sales have closed.
/// Opens the seat map.
class TimeChip extends StatelessWidget {
  const TimeChip({super.key, required this.slot});

  final ShowtimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final time = formatTime(slot.startAt);
    final free = slot.availableSeats;
    final soldOut = free == 0;
    final detail = free == null
        ? slot.auditorium
        : soldOut
        ? 'Hết vé'
        : '$free ghế trống';
    return Semantics(
      label: !slot.bookable
          ? 'Suất $time, đã đóng bán'
          : 'Suất $time, ${soldOut ? 'hết vé' : detail}',
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
                detail,
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
