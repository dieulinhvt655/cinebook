import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/state_views.dart';
import '../../tickets/domain/booking_history.dart';
import '../../tickets/presentation/cubit/booking_history_cubit.dart';
import '../domain/user.dart';
import 'cubit/account_cubit.dart';

/// S14: personal details, transaction history and logout.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _history = sl<BookingHistoryCubit>();

  @override
  void initState() {
    super.initState();
    // The tab stays alive, so this runs once; a payment and pull-to-refresh reload it.
    unawaited(_history.load());
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AccountCubit(sl())..load()),
      BlocProvider.value(value: _history),
    ],
    child: const AccountView(),
  );
}

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final cubit = context.read<AccountCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để đặt vé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) unawaited(cubit.logout());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: BlocBuilder<AccountCubit, AccountState>(
        builder: (context, state) {
          final user = state.user;
          if (user == null) {
            if (state.failure case final f?) {
              return ErrorView(
                message: f.message,
                onRetry: context.read<AccountCubit>().load,
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => Future.wait([
              context.read<AccountCubit>().load(),
              context.read<BookingHistoryCubit>().load(),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: [
                _Profile(user: user),
                const SizedBox(height: AppSpacing.lg),
                const _History(),
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: state.loggingOut ? 'Đang đăng xuất…' : 'Đăng xuất',
                  onPressed: state.loggingOut
                      ? null
                      : () => _confirmLogout(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final dob = user.dateOfBirth;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.fullName),
            subtitle: const Text('Họ tên'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(user.email),
            subtitle: const Text('Email'),
          ),
          if (user.phone case final phone?)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(phone),
              subtitle: const Text('Số điện thoại'),
            ),
          if (dob != null)
            ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: Text(DateFormat('dd/MM/yyyy').format(dob)),
              subtitle: const Text('Ngày sinh'),
            ),
        ],
      ),
    );
  }
}

/// "Lịch sử giao dịch": every booking, newest first. A paid one opens its ticket.
class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<BookingHistoryCubit, BookingHistoryState>(
      builder: (context, state) {
        final items = state.items;
        final Widget body;
        if (items == null) {
          body = state.failure == null
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _Message(
                  'Không tải được lịch sử. ${state.failure!.message}',
                  actionLabel: 'Thử lại',
                  onAction: context.read<BookingHistoryCubit>().load,
                );
        } else if (items.isEmpty) {
          body = const _Message('Bạn chưa có giao dịch nào');
        } else {
          body = Column(
            children: [
              for (final item in items) ...[
                BookingHistoryTile(
                  item: item,
                  onTap: item.status == BookingStatus.paid
                      ? () => context.go(Routes.ticket(item.id))
                      : null,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lịch sử giao dịch', style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            body,
          ],
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (actionLabel case final label?)
          TextButton(onPressed: onAction, child: Text(label)),
      ],
    ),
  );
}

/// Movie, showtime, seats, amount and status of one booking.
class BookingHistoryTile extends StatelessWidget {
  const BookingHistoryTile({super.key, required this.item, this.onTap});

  final BookingHistoryItem item;

  /// Null for a booking without a ticket.
  final VoidCallback? onTap;

  static (String, Color) statusLabel(BookingStatus status) => switch (status) {
    BookingStatus.paid => ('Đã thanh toán', AppColors.success),
    BookingStatus.holding => ('Đang giữ ghế', AppColors.warning),
    BookingStatus.expired => ('Hết hạn giữ ghế', AppColors.textSecondary),
    BookingStatus.cancelled => ('Đã huỷ', AppColors.textSecondary),
    BookingStatus.other => ('Không rõ', AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secondary = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    final show = item.show;
    final (label, color) = statusLabel(item.status);
    final createdAt = toVietnamTime(item.createdAt);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.movieTitle,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${show.cinemaName} · ${formatTime(show.startAt)}, '
                      '${formatDayChip(show.startAt)}',
                      style: secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Ghế: ${item.seats.join(', ')}',
                      style: secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.bookingCode} · '
                      '${DateFormat('HH:mm dd/MM/yyyy').format(createdAt)}',
                      style: secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatVnd(item.totalAmount),
                    style: text.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(label, style: text.labelSmall?.copyWith(color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
