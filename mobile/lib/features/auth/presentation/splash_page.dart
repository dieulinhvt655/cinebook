import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/session/auth_session.dart';

/// S01: restores the session; the router then redirects to Home or Login.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    // Free hosting sleeps when idle; tell the user after 3 s.
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _slow = true);
    });
    unawaited(sl<AuthSession>().restore());
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CineBook',
              style: text.headlineMedium?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            if (_slow) ...[
              const SizedBox(height: 16),
              Text('Đang khởi động máy chủ…', style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
