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

/// Release date etc.: `25/11/2026`.
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// Calendar dates (no time of day) are kept as UTC midnight so the Vietnam-time formatters
/// above show the same day on any device time zone.
DateTime parseIsoDate(String s) {
  final d = DateTime.parse(s);
  return DateTime.utc(d.year, d.month, d.day);
}

/// `2026-11-22`, as the API expects for `?date=`.
String formatIsoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Today's date in Vietnam, as UTC midnight (see [parseIsoDate]).
DateTime vietnamToday([DateTime? now]) {
  final v = toVietnamTime(now ?? DateTime.now());
  return DateTime.utc(v.year, v.month, v.day);
}
