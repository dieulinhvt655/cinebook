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
import '../../showtimes/presentation/cubit/city_cubit.dart';
import '../../showtimes/presentation/widgets/city_button.dart';
import '../domain/movie.dart';
import 'cubit/home_cubit.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/poster_card.dart';

/// S04: city picker, search box, banner carousel, Đang chiếu / Sắp chiếu tabs, 2-column poster grid.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) {
      // Home is the first screen after login: fetch the city list for the picker.
      final city = context.read<CityCubit>();
      if (city.state.cities.isEmpty) unawaited(city.load());
      return HomeCubit(sl(), city: city.state.selected)..load();
    },
    child: BlocListener<CityCubit, CityState>(
      listenWhen: (a, b) => a.selected != b.selected,
      listener: (context, city) =>
          unawaited(context.read<HomeCubit>().changeCity(city.selected)),
      child: const HomeView(),
    ),
  );
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void _open(BuildContext context, MovieSummary m) =>
      unawaited(context.push(Routes.movie(m.id)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CineBook',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
        ),
        actions: const [CityButton()],
      ),
      body: BlocConsumer<HomeCubit, HomeState>(
        listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
        listener: (context, state) {
          // With movies on screen, a failed refresh only shows a snackbar.
          if (state.hasData) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.failure!.message)));
          }
        },
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();
          if (!state.hasData) {
            if (state.failure case final f?) {
              return ErrorView(message: f.message, onRetry: cubit.load);
            }
            return const _HomeSkeleton();
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _SearchBox()),
                if (state.banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: BannerCarousel(
                      movies: state.banners,
                      onTap: (m) => _open(context, m),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    child: SegmentedButton<MovieStatus>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: MovieStatus.nowShowing,
                          label: Text('Đang chiếu'),
                        ),
                        ButtonSegment(
                          value: MovieStatus.comingSoon,
                          label: Text('Sắp chiếu'),
                        ),
                      ],
                      selected: {state.tab},
                      onSelectionChanged: (s) => cubit.selectTab(s.first),
                    ),
                  ),
                ),
                if (state.visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      message: state.tab == MovieStatus.nowShowing
                          ? 'Hiện chưa có phim đang chiếu'
                          : 'Chưa có phim sắp chiếu',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      0,
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.5,
                          ),
                      itemCount: state.visible.length,
                      itemBuilder: (_, i) {
                        final m = state.visible[i];
                        return PosterCard(
                          movie: m,
                          showReleaseDate: state.tab == MovieStatus.comingSoon,
                          onTap: () => _open(context, m),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Looks like a search field; opens S05.
class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.xs,
        AppSpacing.pagePadding,
        AppSpacing.md,
      ),
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          onTap: () => unawaited(context.push(Routes.search)),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  'Tìm phim',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner and 6 poster tiles.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        const AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox()),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 2 / 3,
          children: [for (var i = 0; i < 6; i++) const SkeletonBox()],
        ),
      ],
    );
  }
}
