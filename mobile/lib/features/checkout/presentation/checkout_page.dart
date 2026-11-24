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
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/countdown_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../movies/presentation/widgets/movie_image.dart';
import '../domain/booking.dart';
import '../domain/payment.dart';
import 'cubit/checkout_cubit.dart';
import 'cubit/hold_cubit.dart';
import 'cubit/hold_timer_cubit.dart';
import 'hold_expiry.dart';

/// S10: countdown, movie card, seats and combos with prices, total, age warning and the
/// no-refund policy, "Tôi đồng ý điều khoản", then "Giả lập thành công" / "Giả lập thất bại".
///
/// Success replaces the booking flow with S11; failure opens S11 on top, whose "Thử lại"
/// comes back here with the same countdown.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => HoldCubit(sl(), bookingId)..load()),
      BlocProvider(create: (_) => HoldTimerCubit(sl())),
      BlocProvider(create: (_) => CheckoutCubit(sl(), bookingId)),
    ],
    child: const CheckoutView(),
  );
}

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  bool _leaving = false;

  void _onLoaded(Booking booking) {
    final timer = context.read<HoldTimerCubit>()..start(booking.expiresAt);
    if (!booking.isHolding || timer.state.isExpired) unawaited(_expired());
  }

  /// Also covers S11 (failure) when it is open on top.
  Future<void> _expired() async {
    if (_leaving) return;
    _leaving = true;
    await showHoldExpiredDialog(context);
    if (mounted) popThisScreen(context, HoldExit.expired);
  }

  Future<void> _pay(PaymentResult result) async {
    final checkout = context.read<CheckoutCubit>();
    final payment = await checkout.pay(result);
    if (payment == null || !mounted) return;
    if (payment.succeeded) {
      _leaving = true;
      // Paid: the seat map, combos and checkout are behind us for good.
      context.go(Routes.result(checkout.bookingId, success: true));
    } else {
      await context.push(Routes.result(checkout.bookingId, success: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HoldCubit, HoldState>(
          listenWhen: (a, b) => b.booking != null && a.booking != b.booking,
          listener: (_, state) => _onLoaded(state.booking!),
        ),
        BlocListener<HoldTimerCubit, HoldTimerState>(
          listenWhen: (a, b) => !a.isExpired && b.isExpired,
          listener: (_, _) => unawaited(_expired()),
        ),
        BlocListener<CheckoutCubit, CheckoutState>(
          listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
          listener: (context, state) {
            final f = state.notice!.failure;
            if (f.code == 'HOLD_EXPIRED') {
              unawaited(_expired());
              return;
            }
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    f.isConnectivity
                        ? '${f.message}. Bấm thanh toán lại, bạn sẽ '
                              'không bị trừ tiền hai lần.'
                        : f.message,
                  ),
                ),
              );
          },
        ),
      ],
      child: BlocBuilder<CheckoutCubit, CheckoutState>(
        builder: (context, checkout) => PopScope(
          // No leaving while the payment is being processed.
          canPop: !checkout.paying,
          child: Stack(
            children: [
              BlocBuilder<HoldCubit, HoldState>(
                builder: (context, state) => Scaffold(
                  appBar: AppBar(title: const Text('Xác nhận & thanh toán')),
                  body: switch ((state.booking, state.failure)) {
                    (null, final f?) => ErrorView(
                      message: f.message,
                      onRetry: context.read<HoldCubit>().load,
                    ),
                    (null, _) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    (final b?, _) => _Body(booking: b, checkout: checkout),
                  },
                  bottomNavigationBar: state.booking == null
                      ? null
                      : _PayBar(checkout: checkout, onPay: _pay),
                ),
              ),
              if (checkout.paying) const _PayingOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.checkout});

  final Booking booking;
  final CheckoutState checkout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final show = booking.show;
    return Column(
      children: [
        BlocBuilder<HoldTimerCubit, HoldTimerState>(
          builder: (_, timer) => CountdownBanner(remaining: timer.remaining),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 96,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${show.cinemaName} · ${show.auditoriumName}\n'
                          '${formatTime(show.startAt)}, '
                          '${formatDayChip(show.startAt)} · ${show.format}',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              for (final s in booking.seats)
                _Line(label: 'Ghế ${s.label}', amount: s.price),
              for (final c in booking.combos)
                _Line(
                  label: '${c.name} × ${c.quantity}',
                  amount: c.unitPrice * c.quantity,
                ),
              const Divider(height: AppSpacing.lg),
              _Line(
                label: 'Tổng cộng',
                amount: booking.totalAmount,
                bold: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _Notice(ageRating: show.ageRating),
              const SizedBox(height: AppSpacing.xs),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: checkout.agreed,
                onChanged: checkout.paying
                    ? null
                    : (v) => context.read<CheckoutCubit>().agree(v ?? false),
                title: const Text('Tôi đồng ý điều khoản'),
              ),
              Text(
                'Mã đơn: ${booking.bookingCode} · Thanh toán giả lập',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.amount, this.bold = false});

  final String label;
  final int amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatVnd(amount), style: style),
        ],
      ),
    );
  }
}

/// Yellow box: who may watch the film and the no-refund policy.
class _Notice extends StatelessWidget {
  const _Notice({required this.ageRating});

  final String ageRating;

  static String ageText(String rating) => switch (rating) {
    'P' => 'Phim được phổ biến đến người xem ở mọi độ tuổi.',
    'K' =>
      'Phim dành cho khán giả dưới 13 tuổi khi xem cùng cha, mẹ hoặc '
          'người giám hộ.',
    'T13' => 'Phim dành cho khán giả từ đủ 13 tuổi trở lên.',
    'T16' => 'Phim dành cho khán giả từ đủ 16 tuổi trở lên.',
    _ => 'Phim dành cho khán giả từ đủ 18 tuổi trở lên.',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$ageRating: ${ageText(ageRating)} Rạp có thể kiểm tra giấy tờ.',
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text('Vé đã thanh toán không thể huỷ hoặc hoàn tiền.'),
        ],
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({required this.checkout, required this.onPay});

  final CheckoutState checkout;
  final Future<void> Function(PaymentResult) onPay;

  @override
  Widget build(BuildContext context) {
    final enabled = checkout.canPay;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSpacing.buttonHeight,
                  child: SecondaryButton(
                    label: 'Giả lập thất bại',
                    onPressed: enabled
                        ? () => unawaited(onPay(PaymentResult.failed))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: AppSpacing.buttonHeight,
                  child: PrimaryButton(
                    label: 'Giả lập thành công',
                    onPressed: enabled
                        ? () => unawaited(onPay(PaymentResult.success))
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayingOverlay extends StatelessWidget {
  const _PayingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0xAA000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Material(
                type: MaterialType.transparency,
                child: Text('Đang xử lý thanh toán…'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
