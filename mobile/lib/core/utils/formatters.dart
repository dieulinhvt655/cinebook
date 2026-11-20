import 'package:intl/intl.dart';

/// Money: `95.000 đ` (VND has no minor unit).
String formatVnd(int amount) =>
    '${NumberFormat.decimalPattern('vi').format(amount)} đ';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Day chip: `T6, 21/11` (shown in Vietnam time).
String formatDayChip(DateTime d) {
  final local = toVietnamTime(d);
  return '${_weekdays[local.weekday - 1]}, ${DateFormat('dd/MM').format(local)}';
}

/// Showtime: `19:30` (Vietnam time).
String formatTime(DateTime d) => DateFormat('HH:mm').format(toVietnamTime(d));

/// Countdown: `08:42`.
String formatCountdown(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// The API sends UTC; Vietnam is UTC+7 with no DST.
DateTime toVietnamTime(DateTime d) => d.toUtc().add(const Duration(hours: 7));
