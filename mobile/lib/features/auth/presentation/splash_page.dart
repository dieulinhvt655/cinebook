import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/state_views.dart';
import 'cubit/splash_cubit.dart';

/// S01: checks the stored session with the server (BR-07.2) and wakes the free-tier server;
/// the router then moves to Home or Login.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SplashCubit(sl())..check(),
    child: const SplashView(),
  );
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _startSlowTimer();
  }

  // Free hosting sleeps when idle; tell the user after 3 s.
  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  void _retry() {
    setState(_startSlowTimer);
    unawaited(context.read<SplashCubit>().check());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: BlocBuilder<SplashCubit, ApiFailure?>(
        builder: (context, failure) {
          if (failure != null) {
            return ErrorView(message: failure.message, onRetry: _retry);
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CineBook',
                  style: text.headlineMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                if (_slow) ...[
                  const SizedBox(height: 16),
                  Text('Đang khởi động máy chủ…', style: text.bodyMedium),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
