import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/seat_map.dart';
import '../../domain/seat_map_repository.dart';
import '../../domain/seat_selection.dart';

/// One-off message shown as a snackbar; [id] changes for every new message.
class SeatNotice extends Equatable {
  const SeatNotice(this.id, this.message);

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class SeatMapState extends Equatable {
  const SeatMapState({
    this.map,
    this.failure,
    this.loading = false,
    this.selected = const {},
    this.notice,
  });

  /// Null until loaded once.
  final SeatMap? map;

  /// Error of the first load (full-screen); later failures become a [notice].
  final ApiFailure? failure;
  final bool loading;

  /// Ids of the seats picked on this device.
  final Set<int> selected;
  final SeatNotice? notice;

  List<Seat> get selectedSeats =>
      map == null ? const [] : SeatSelection.seatsOf(map!, selected);

  /// Σ seat price: base price + type surcharge for each seat.
  int get total => selectedSeats.fold(0, (sum, s) => sum + s.price);

  bool get canContinue =>
      selected.isNotEmpty && (map?.bookable ?? false) && !loading;

  SeatMapState copyWith({
    SeatMap? map,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loading,
    Set<int>? selected,
    SeatNotice? notice,
  }) => SeatMapState(
    map: map ?? this.map,
    failure: clearFailure ? null : failure ?? this.failure,
    loading: loading ?? this.loading,
    selected: selected ?? this.selected,
    notice: notice ?? this.notice,
  );

  @override
  List<Object?> get props => [map, failure, loading, selected, notice];
}

/// S08 (F4): loads the room, applies the selection rules and keeps a running total.
class SeatMapCubit extends Cubit<SeatMapState> {
  SeatMapCubit(this._repo, this.showtimeId) : super(const SeatMapState());

  final SeatMapRepository _repo;
  final int showtimeId;
  int _notices = 0;

  /// First load and refresh. Seats picked here that someone else took meanwhile are
  /// dropped from the selection, with a message naming them.
  Future<void> load() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final map = await _repo.forShowtime(showtimeId);
      if (isClosed) return;
      final kept = {
        for (final id in state.selected)
          if (map.seatById(id)?.isAvailable ?? false) id,
      };
      final lost = state.map == null
          ? const <Seat>[]
          : SeatSelection.seatsOf(state.map!, state.selected.difference(kept));
      emit(
        state.copyWith(
          map: map,
          loading: false,
          selected: kept,
          notice: lost.isEmpty
              ? null
              : _notice(
                  'Ghế ${lost.map((s) => s.label).join(', ')} '
                  'vừa được người khác chọn',
                ),
        ),
      );
    } on ApiFailure catch (f) {
      if (isClosed) return;
      emit(
        state.map == null
            ? state.copyWith(loading: false, failure: f)
            : state.copyWith(loading: false, notice: _notice(f.message)),
      );
    }
  }

  void toggle(Seat seat) {
    final map = state.map;
    if (map == null || !map.bookable) return;
    final result = SeatSelection.toggle(map, state.selected, seat);
    emit(
      state.copyWith(
        selected: result.selected,
        notice: result.limitReached
            ? _notice('Tối đa ${map.maxSeats} ghế mỗi lần đặt')
            : null,
      ),
    );
  }

  /// "Tiếp tục": returns the seats to hold, or null (with a message) when the selection
  /// would leave a single seat stranded.
  List<Seat>? confirm() {
    final map = state.map;
    if (map == null || !state.canContinue) return null;
    final orphan = SeatSelection.findOrphan(map, state.selected);
    if (orphan != null) {
      emit(
        state.copyWith(
          notice: _notice(
            'Không được để trống ghế lẻ ${orphan.label}, vui lòng chọn lại',
          ),
        ),
      );
      return null;
    }
    return state.selectedSeats;
  }

  SeatNotice _notice(String message) => SeatNotice(++_notices, message);
}
