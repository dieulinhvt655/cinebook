import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/movie.dart';
import 'cubit/search_cubit.dart';
import 'widgets/movie_image.dart';

/// S05: search box (300 ms debounce), recent searches, results as a list.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SearchCubit(sl(), sl()),
    child: const SearchView(),
  );
}

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _useRecent(String q) {
    _field.text = q;
    unawaited(context.read<SearchCubit>().submit(q));
  }

  void _open(MovieSummary m) {
    context.read<SearchCubit>().opened();
    unawaited(context.push(Routes.movie(m.id)));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocBuilder<SearchCubit, SearchState>(
          buildWhen: (a, b) => a.loading != b.loading,
          builder: (context, state) => TextField(
            controller: _field,
            autofocus: true,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            onChanged: (t) {
              setState(() {}); // Clear button.
              cubit.changed(t);
            },
            onSubmitted: cubit.submit,
            decoration: InputDecoration(
              hintText: 'Tìm phim',
              counterText: '',
              border: InputBorder.none,
              suffixIcon: state.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _field.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _field.clear();
                        setState(() {});
                        cubit.changed('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: BlocConsumer<SearchCubit, SearchState>(
        listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.failure!.message))),
        builder: (context, state) {
          final results = state.results;
          if (results == null) {
            return _RecentList(
              items: state.recent,
              onTap: _useRecent,
              onRemove: cubit.removeRecent,
            );
          }
          if (results.isEmpty) {
            return EmptyView(
              icon: Icons.search_off,
              message: 'Không tìm thấy phim cho “${state.query}”',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _ResultTile(movie: results[i], onTap: () => _open(results[i])),
          );
        },
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.items,
    required this.onTap,
    required this.onRemove,
  });

  final List<String> items;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.md,
            AppSpacing.pagePadding,
            AppSpacing.xs,
          ),
          child: Text(
            'Tìm gần đây',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final q in items)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(q),
            onTap: () => onTap(q),
            trailing: IconButton(
              tooltip: 'Xoá khỏi lịch sử',
              icon: const Icon(Icons.close),
              onPressed: () => onRemove(q),
            ),
          ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.movie, required this.onTap});

  final MovieSummary movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 84,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                child: MovieImage(url: movie.posterUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      AgeRatingBadge(movie.ageRating),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${movie.durationMin} phút',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (movie.genres.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      movie.genres.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
