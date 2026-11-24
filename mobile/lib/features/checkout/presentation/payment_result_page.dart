import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_buttons.dart';
import 'cubit/hold_cubit.dart';

/// S11. Success: icon, booking code, "Xem vé". Failure: the reason and "Thử lại", which
/// returns to S10 with the countdown still running (S10 handles the hold running out).
class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({
    super.key,
    required this.bookingId,
    required this.success,
  });

  final int bookingId;
  final bool success;

  @override
  Widget build(BuildContext context) => success
      ? BlocProvider(
          create: (_) => HoldCubit(sl(), bookingId)..load(),
          child: const PaymentSuccessView(),
        )
      : const PaymentFailedView();
}

class PaymentSuccessView extends StatelessWidget {
  const PaymentSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Thanh toán thành công', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              BlocBuilder<HoldCubit, HoldState>(
                builder: (_, state) => Text(
                  switch (state.booking) {
                    final b? =>
                      'Mã đặt vé ${b.bookingCode} · ${formatVnd(b.totalAmount)}',
                    null => '',
                  },
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: PrimaryButton(
                  label: 'Xem vé',
                  onPressed: () => context.go(Routes.tickets),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentFailedView extends StatelessWidget {
  const PaymentFailedView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thanh toán')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, size: 80, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Thanh toán thất bại', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Giao dịch giả lập bị từ chối, bạn chưa bị trừ tiền. Ghế vẫn '
              'được giữ đến hết thời gian giữ ghế.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: PrimaryButton(
                label: 'Thử lại',
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
