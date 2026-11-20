import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../utils/formatters.dart';

/// "Thời gian giữ ghế 08:42"; turns orange in the last minute.
class CountdownBanner extends StatelessWidget {
  const CountdownBanner({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final warning = remaining < const Duration(minutes: 1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: warning ? AppColors.warning : AppColors.surfaceVariant,
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: AppSpacing.xs),
          const Text('Thời gian giữ ghế'),
          const Spacer(),
          Text(
            formatCountdown(remaining),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
