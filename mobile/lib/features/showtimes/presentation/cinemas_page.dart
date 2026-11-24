import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import 'cubit/cinemas_cubit.dart';
import 'cubit/city_cubit.dart';
import 'widgets/city_button.dart';

/// "Rạp" tab: cinemas of the city picked in the app bar; a cinema opens its schedule.
class CinemasPage extends StatelessWidget {
  const CinemasPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        CinemasCubit(sl(), city: context.read<CityCubit>().state.selected)
          ..load(),
    child: BlocListener<CityCubit, CityState>(
      listenWhen: (a, b) => a.selected != b.selected,
      listener: (context, city) =>
          unawaited(context.read<CinemasCubit>().changeCity(city.selected)),
      child: const CinemasView(),
    ),
  );
}

class CinemasView extends StatelessWidget {
  const CinemasView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rạp'), actions: const [CityButton()]),
      body: BlocBuilder<CinemasCubit, CinemasState>(
        builder: (context, state) {
          final cubit = context.read<CinemasCubit>();
          if (state.failure case final f?) {
            return ErrorView(message: f.message, onRetry: cubit.load);
          }
          final cinemas = state.cinemas;
          if (cinemas == null) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: [
                for (var i = 0; i < 3; i++) ...[
                  const SkeletonBox(height: 72),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }
          if (cinemas.isEmpty) {
            return const EmptyView(
              icon: Icons.location_city_outlined,
              message: 'Chưa có rạp ở thành phố này',
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              itemCount: cinemas.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = cinemas[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.theaters_outlined),
                    title: Text(c.name),
                    subtitle: Text(
                      c.address,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(context.push(Routes.cinema(c.id))),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
