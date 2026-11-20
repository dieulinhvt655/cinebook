import 'package:cinebook/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  test('money uses dot grouping and đ', () {
    expect(formatVnd(95000), '95.000 đ');
    expect(formatVnd(1250000), '1.250.000 đ');
  });

  test('dates are shown in Vietnam time', () {
    // 17:30 UTC on Fri 20/11 is 00:30 on Sat 21/11 in Vietnam (UTC+7).
    final t = DateTime.utc(2026, 11, 20, 17, 30);
    expect(formatDayChip(t), 'T7, 21/11');
    expect(formatTime(t), '00:30');
    expect(formatDayChip(DateTime.utc(2026, 11, 21, 12, 30)), 'T7, 21/11');
    expect(formatTime(DateTime.utc(2026, 11, 21, 12, 30)), '19:30');
  });

  test('countdown is mm:ss', () {
    expect(formatCountdown(const Duration(minutes: 8, seconds: 42)), '08:42');
    expect(formatCountdown(const Duration(minutes: 10)), '10:00');
  });
}
