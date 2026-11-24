import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/booking.dart';
import '../../domain/booking_repository.dart';
import '../../domain/combo.dart';

class CombosState extends Equatable {
  const CombosState({
    this.combos,
    this.failure,
    this.quantities = const {},
    this.saving = false,
  });

  /// Null until loaded.
  final List<Combo>? combos;

  /// The list could not load; "Bỏ qua" still works so checkout is never blocked.
  final ApiFailure? failure;

  /// Combo id → quantity (only ids with quantity > 0).
  final Map<int, int> quantities;
  final bool saving;

  int quantityOf(int comboId) => quantities[comboId] ?? 0;

  bool get hasSelection => quantities.isNotEmpty;

  /// Preview of the combo total; the server's figure is the one charged.
  int get total => [
    for (final c in combos ?? const <Combo>[]) c.price * quantityOf(c.id),
  ].fold(0, (a, b) => a + b);

  CombosState copyWith({
    List<Combo>? combos,
    ApiFailure? failure,
    bool clearFailure = false,
    Map<int, int>? quantities,
    bool? saving,
  }) => CombosState(
    combos: combos ?? this.combos,
    failure: clearFailure ? null : failure ?? this.failure,
    quantities: quantities ?? this.quantities,
    saving: saving ?? this.saving,
  );

  @override
  List<Object?> get props => [combos, failure, quantities, saving];
}

/// S09: the combo list with +/− steppers, saved to the booking on "Tiếp tục".
class CombosCubit extends Cubit<CombosState> {
  CombosCubit(this._repo) : super(const CombosState());

  final BookingRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(clearFailure: true));
    try {
      final combos = await _repo.combos();
      if (!isClosed) emit(state.copyWith(combos: combos));
    } on ApiFailure catch (f) {
      if (!isClosed) emit(state.copyWith(failure: f));
    }
  }

  /// Starts from what the booking already has (coming back from S10).
  void startFrom(Booking booking) =>
      emit(state.copyWith(quantities: booking.comboQuantities));

  void add(Combo c) => _set(c.id, state.quantityOf(c.id) + 1);

  void remove(Combo c) => _set(c.id, state.quantityOf(c.id) - 1);

  void _set(int id, int quantity) {
    if (quantity > Combo.maxQuantity) return;
    final next = Map.of(state.quantities);
    if (quantity <= 0) {
      next.remove(id);
    } else {
      next[id] = quantity;
    }
    emit(state.copyWith(quantities: next));
  }

  /// Saves the picks to [booking] and returns the updated booking (unchanged picks
  /// need no request). Throws `ApiFailure`, e.g. HOLD_EXPIRED.
  Future<Booking> save(Booking booking) async {
    if (_same(state.quantities, booking.comboQuantities)) return booking;
    emit(state.copyWith(saving: true));
    try {
      return await _repo.setCombos(booking.id, state.quantities);
    } finally {
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }

  static bool _same(Map<int, int> a, Map<int, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
