import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'di.dart';
import 'theme/app_theme.dart';

class CineBookApp extends StatelessWidget {
  const CineBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CineBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: sl<GoRouter>(),
      // Support system text scale up to 1.3x (design doc 4.4).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
    );
  }
}
