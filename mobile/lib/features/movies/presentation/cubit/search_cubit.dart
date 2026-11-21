import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/movie.dart';
import '../../domain/movie_repository.dart';
import '../recent_searches.dart';

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.results,
    this.loading = false,
    this.failure,
    this.recent = const [],
  });

  /// Trimmed text the [results] belong to.
  final String query;

  /// Null while nothing has been searched for (the recent list is shown instead).
  final List<MovieSummary>? results;
  final bool loading;

  /// Last search error; [results] keeps the previous answer.
  final ApiFailure? failure;
  final List<String> recent;

  @override
  List<Object?> get props => [query, results, loading, failure, recent];
}

/// S05: searches 300 ms after the user stops typing. Answers to older queries are dropped.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(
    this._repo,
    this._recent, {
    this.debounce = const Duration(milliseconds: 300),
  }) : super(SearchState(recent: _recent.items));

  final MovieRepository _repo;
  final RecentSearches _recent;
  final Duration debounce;
  Timer? _timer;
  int _request = 0;

  void changed(String text) {
    _timer?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      _request++;
      emit(SearchState(recent: _recent.items));
      return;
    }
    _timer = Timer(debounce, () => _search(q));
  }

  /// Keyboard "search": no waiting, and the text goes into the recent list.
  Future<void> submit(String text) {
    _timer?.cancel();
    final q = text.trim();
    if (q.isEmpty) return Future.value();
    _recent.add(q);
    return _search(q);
  }

  /// A result was opened: remember what led to it.
  void opened() {
    _recent.add(state.query);
    emit(_copy(recent: _recent.items));
  }

  void removeRecent(String q) {
    _recent.remove(q);
    emit(_copy(recent: _recent.items));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    emit(_copy(loading: true, keepFailure: false));
    try {
      final results = await _repo.movies(query: q);
      if (id != _request || isClosed) return;
      emit(SearchState(query: q, results: results, recent: _recent.items));
    } on ApiFailure catch (f) {
      if (id != _request || isClosed) return;
      emit(_copy(loading: false, failure: f));
    }
  }

  SearchState _copy({
    bool? loading,
    ApiFailure? failure,
    List<String>? recent,
    bool keepFailure = true,
  }) => SearchState(
    query: state.query,
    results: state.results,
    loading: loading ?? state.loading,
    failure: failure ?? (keepFailure ? state.failure : null),
    recent: recent ?? state.recent,
  );

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
