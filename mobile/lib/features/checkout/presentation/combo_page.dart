import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/countdown_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/booking.dart';
import '../domain/combo.dart';
import 'cubit/combos_cubit.dart';
import 'cubit/hold_cubit.dart';
import 'cubit/hold_timer_cubit.dart';
import 'hold_expiry.dart';

/// S09: countdown, combo list with +/− steppers, "Bỏ qua" / "Tiếp tục" to S10.
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
      BlocProvider(create: (_) => CombosCubit(sl())..load()),
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
  bool _started = false;

  void _onLoaded(Booking booking) {
    if (!_started) {
      _started = true;
      context.read<CombosCubit>().startFrom(booking);
    }
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
    await showHoldExpiredDialog(context);
    if (mounted) popThisScreen(context);
  }

  /// "Bỏ qua" / "Tiếp tục": saves the combos, then S10. S10 reports an expired hold
  /// back here, and this screen closes too.
  Future<void> _next(Booking booking) async {
    final combos = context.read<CombosCubit>();
    final hold = context.read<HoldCubit>();
    try {
      await combos.save(booking);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      if (f.code == 'HOLD_EXPIRED') return _expired();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message)));
      return;
    }
    if (!mounted) return;
    final exit = await context.push<HoldExit>(Routes.checkout(booking.id));
    if (!mounted) return;
    if (exit == HoldExit.expired) {
      _leaving = true;
      context.pop();
    } else {
      await hold.load(); // totals as the server has them now
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
          // While S10 is on top, S10 handles the expiry and reports back.
          listenWhen: (a, b) =>
              !a.isExpired &&
              b.isExpired &&
              (ModalRoute.of(context)?.isCurrent ?? true),
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
                  : _Bar(booking: booking, onNext: () => _next(booking)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.sm,
            AppSpacing.pagePadding,
            0,
          ),
          child: Text(
            'Ghế: ${booking.seats.map((s) => s.label).join(', ')}',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: BlocBuilder<CombosCubit, CombosState>(
            builder: (context, state) {
              final cubit = context.read<CombosCubit>();
              final combos = state.combos;
              if (combos == null) {
                if (state.failure case final f?) {
                  // Never blocks checkout: "Bỏ qua" below still works.
                  return EmptyView(
                    icon: Icons.fastfood_outlined,
                    message: 'Không tải được combo. ${f.message}',
                    actionLabel: 'Thử lại',
                    onAction: cubit.load,
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }
              if (combos.isEmpty) {
                return const EmptyView(
                  icon: Icons.fastfood_outlined,
                  message: 'Hiện chưa có combo',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                itemCount: combos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => ComboTile(
                  combo: combos[i],
                  quantity: state.quantityOf(combos[i].id),
                  onAdd: () => cubit.add(combos[i]),
                  onRemove: () => cubit.remove(combos[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Name, description, price and a +/− stepper.
class ComboTile extends StatelessWidget {
  const ComboTile({
    super.key,
    required this.combo,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Combo combo;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
              child: const Icon(Icons.fastfood_outlined),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(combo.name, style: text.titleSmall),
                  if (combo.description case final d?)
                    Text(
                      d,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Text(formatVnd(combo.price), style: text.bodyMedium),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Bớt ${combo.name}',
              onPressed: quantity > 0 ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Thêm ${combo.name}',
              onPressed: quantity < Combo.maxQuantity ? onAdd : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.booking, required this.onNext});

  final Booking booking;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<CombosCubit, CombosState>(
      builder: (context, combos) => Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatVnd(booking.seatTotal + combos.total),
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
                    label: combos.hasSelection ? 'Tiếp tục' : 'Bỏ qua',
                    loading: combos.saving,
                    onPressed: () => unawaited(onNext()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
