import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/movie.dart';
import '../../domain/movie_repository.dart';

class MovieDetailState extends Equatable {
  const MovieDetailState({this.movie, this.failure});

  final MovieDetail? movie;
  final ApiFailure? failure;

  bool get loading => movie == null && failure == null;

  @override
  List<Object?> get props => [movie, failure];
}

/// S06.
class MovieDetailCubit extends Cubit<MovieDetailState> {
  MovieDetailCubit(this._repo, this.movieId) : super(const MovieDetailState());

  final MovieRepository _repo;
  final int movieId;

  static const notShowing = 'Phim không còn chiếu';

  Future<void> load() async {
    emit(const MovieDetailState());
    try {
      emit(MovieDetailState(movie: await _repo.detail(movieId)));
    } on ApiFailure catch (f) {
      emit(
        MovieDetailState(
          failure: f.status == 404
              ? ApiFailure(code: f.code, message: notShowing, status: 404)
              : f,
        ),
      );
    }
  }
}
