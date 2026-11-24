import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/seat_map.dart';

/// One seat (or one couple pair, [seats] of length 2) in 5 states × 3 kinds. Every state
/// has a non-colour cue too: check = selected, × = sold, clock = held (design doc 4.5).
class SeatTile extends StatelessWidget {
  const SeatTile({
    super.key,
    required this.seats,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final List<Seat> seats;
  final bool selected;

  /// Width and height of one grid cell; a pair spans two cells.
  final double size;
  final VoidCallback? onTap;

  Seat get _seat => seats.first;

  static Color borderOf(SeatKind kind) => switch (kind) {
    SeatKind.vip => AppColors.seatVip,
    SeatKind.couple => AppColors.seatCouple,
    SeatKind.standard => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final status = _seat.status;
    final (Color fill, Color border, IconData? icon) = switch (status) {
      _ when selected => (AppColors.primary, AppColors.primary, Icons.check),
      SeatStatus.sold => (AppColors.seatSold, AppColors.seatSold, Icons.close),
      SeatStatus.held => (
        AppColors.seatHeld,
        AppColors.seatHeld,
        Icons.schedule,
      ),
      SeatStatus.available => (Colors.transparent, borderOf(_seat.kind), null),
    };
    final label = seats.map((s) => s.label).join('-');
    final stateText = selected
        ? 'đang chọn'
        : switch (status) {
            SeatStatus.sold => 'đã bán',
            SeatStatus.held => 'đang được giữ',
            SeatStatus.available => 'trống',
          };
    final gap = size * 0.1;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: 'Ghế $label, ${formatVnd(_seat.price)}, $stateText',
      excludeSemantics: true,
      child: SizedBox(
        width: size * seats.length,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: border, width: 1.5),
              borderRadius: BorderRadius.circular(size * 0.2),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size * 0.2),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: size * 0.5, color: AppColors.onPrimary)
                    : FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Text(
                            seats.length == 1
                                ? '${_seat.col}'
                                : '${seats.first.col}-${seats.last.col}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The curved "MÀN HÌNH" line above the seats.
class ScreenCurve extends StatelessWidget {
  const ScreenCurve({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 24,
          width: double.infinity,
          child: CustomPaint(painter: _CurvePainter()),
        ),
        Text(
          'MÀN HÌNH',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.1, size.height)
      ..quadraticBezierTo(size.width / 2, 0, size.width * 0.9, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Two-row key: states, then the seat types present in the room with their price.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, required this.types});

  final List<SeatTypeInfo> types;

  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, Color border, IconData? icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon == null
              ? null
              : Icon(icon, size: 12, color: AppColors.onPrimary),
        ),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            item(Colors.transparent, AppColors.textSecondary, null, 'Trống'),
            item(
              AppColors.primary,
              AppColors.primary,
              Icons.check,
              'Đang chọn',
            ),
            item(AppColors.seatSold, AppColors.seatSold, Icons.close, 'Đã bán'),
            item(
              AppColors.seatHeld,
              AppColors.seatHeld,
              Icons.schedule,
              'Đang giữ',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final t in types)
              item(
                Colors.transparent,
                SeatTile.borderOf(t.kind),
                null,
                '${t.name} ${formatVnd(t.price)}',
              ),
          ],
        ),
      ],
    );
  }
}
