import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/countdown_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/booking.dart';
import 'cubit/hold_cubit.dart';
import 'cubit/hold_timer_cubit.dart';

/// S09: the held seats with the 10-minute countdown. Combos arrive with F6; for now the
/// screen confirms the hold and leads on to checkout.
///
/// Back asks "Huỷ giữ ghế?" and releases the seats; when time runs out a dialog that
/// cannot be dismissed sends the user back to the seat map (S08).
class ComboPage extends StatelessWidget {
  const ComboPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => HoldCubit(sl(), bookingId)..load()),
      BlocProvider(create: (_) => HoldTimerCubit(sl())),
    ],
    child: const ComboView(),
  );
}

class ComboView extends StatefulWidget {
  const ComboView({super.key});

  @override
  State<ComboView> createState() => _ComboViewState();
}

class _ComboViewState extends State<ComboView> {
  /// Set once the user leaves (cancelled or expired), so the page pops only once.
  bool _leaving = false;

  void _onLoaded(Booking booking) {
    final timer = context.read<HoldTimerCubit>()..start(booking.expiresAt);
    if (!booking.isHolding || timer.state.isExpired) unawaited(_expired());
  }

  Future<void> _askCancel() async {
    if (_leaving) return;
    final hold = context.read<HoldCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ giữ ghế?'),
        content: const Text(
          'Các ghế bạn đang giữ sẽ được nhả cho người khác đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Huỷ giữ ghế'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _leaving) return;
    final released = await hold.cancel();
    if (!mounted || _leaving) return;
    _leaving = true;
    if (!released) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa huỷ được giữ ghế, ghế sẽ tự nhả khi hết thời gian giữ',
          ),
        ),
      );
    }
    context.pop();
  }

  Future<void> _expired() async {
    if (_leaving) return;
    _leaving = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Hết thời gian giữ ghế'),
          content: const Text(
            'Ghế đã được nhả cho người khác. Vui lòng chọn lại ghế.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chọn lại ghế'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    // The hold can run out while S10 is open on top: close everything down to S08.
    final self = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == self);
    context.pop();
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
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_askCancel());
        },
        child: BlocBuilder<HoldCubit, HoldState>(
          builder: (context, state) {
            final booking = state.booking;
            return Scaffold(
              appBar: AppBar(title: const Text('Combo bắp nước')),
              body: switch ((booking, state.failure)) {
                (null, final f?) => ErrorView(
                  message: f.message,
                  onRetry: context.read<HoldCubit>().load,
                ),
                (null, _) => const Center(child: CircularProgressIndicator()),
                (final b?, _) => _Body(booking: b),
              },
              bottomNavigationBar: booking == null
                  ? null
                  : _Bar(booking: booking, cancelling: state.cancelling),
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        BlocBuilder<HoldTimerCubit, HoldTimerState>(
          builder: (_, timer) => CountdownBanner(remaining: timer.remaining),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Text('Ghế đang giữ', style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final s in booking.seats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(child: Text('Ghế ${s.label}')),
                      Text(formatVnd(s.price)),
                    ],
                  ),
                ),
              const Divider(height: AppSpacing.lg),
              Text(
                'Mã đơn: ${booking.bookingCode}',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const EmptyView(
                icon: Icons.fastfood_outlined,
                message: 'Combo bắp nước sẽ sớm có mặt',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.booking, required this.cancelling});

  final Booking booking;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatVnd(booking.totalAmount),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                height: AppSpacing.buttonHeight,
                child: PrimaryButton(
                  label: 'Tiếp tục',
                  loading: cancelling,
                  onPressed: () =>
                      unawaited(context.push(Routes.checkout(booking.id))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
