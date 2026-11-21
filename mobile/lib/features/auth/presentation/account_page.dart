import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/user.dart';
import 'cubit/account_cubit.dart';

/// S14: personal details and logout. Transaction history arrives with the tickets feature.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AccountCubit(sl())..load(),
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
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              _Profile(user: user),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: state.loggingOut ? 'Đang đăng xuất…' : 'Đăng xuất',
                onPressed: state.loggingOut
                    ? null
                    : () => _confirmLogout(context),
              ),
            ],
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
