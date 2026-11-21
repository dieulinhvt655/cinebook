import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/movie.dart';
import '../../domain/movie_repository.dart';

class HomeState extends Equatable {
  const HomeState({
    this.tab = MovieStatus.nowShowing,
    this.nowShowing,
    this.comingSoon,
    this.loading = false,
    this.failure,
  });

  final MovieStatus tab;

  /// Null until loaded once.
  final List<MovieSummary>? nowShowing;
  final List<MovieSummary>? comingSoon;
  final bool loading;

  /// Set when the last load failed; earlier lists are kept.
  final ApiFailure? failure;

  bool get hasData => nowShowing != null;

  List<MovieSummary> get visible =>
      (tab == MovieStatus.nowShowing ? nowShowing : comingSoon) ?? const [];

  /// Carousel: the first now-showing movies.
  List<MovieSummary> get banners => (nowShowing ?? const []).take(5).toList();

  HomeState copyWith({
    MovieStatus? tab,
    List<MovieSummary>? nowShowing,
    List<MovieSummary>? comingSoon,
    bool? loading,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => HomeState(
    tab: tab ?? this.tab,
    nowShowing: nowShowing ?? this.nowShowing,
    comingSoon: comingSoon ?? this.comingSoon,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [tab, nowShowing, comingSoon, loading, failure];
}

/// S04: both tabs are loaded together so switching tabs is instant.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repo) : super(const HomeState());

  final MovieRepository _repo;

  Future<void> load() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final results = await Future.wait([
        _repo.movies(status: MovieStatus.nowShowing),
        _repo.movies(status: MovieStatus.comingSoon),
      ]);
      emit(
        state.copyWith(
          nowShowing: results[0],
          comingSoon: results[1],
          loading: false,
        ),
      );
    } on ApiFailure catch (f) {
      emit(state.copyWith(loading: false, failure: f));
    }
  }

  void selectTab(MovieStatus tab) => emit(state.copyWith(tab: tab));
}
