import 'package:cinebook/app/di.dart';
import 'package:cinebook/core/storage/app_preferences.dart';
import 'package:cinebook/features/showtimes/domain/cinema.dart';
import 'package:cinebook/features/showtimes/domain/cinema_repository.dart';
import 'package:cinebook/features/showtimes/presentation/cinema_schedule_page.dart';
import 'package:cinebook/features/showtimes/presentation/cinemas_page.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/city_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../movies/catalog_fixtures.dart';

class _Repo extends Mock implements CinemaRepository {}

void main() {
  late _Repo repo;
  late CityCubit city;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000));
    return initializeDateFormatting('vi');
  });

  setUp(() async {
    repo = _Repo();
    sl.registerSingleton<CinemaRepository>(repo);
    SharedPreferences.setMockInitialValues({'city': 'Hà Nội'});
    city = CityCubit(
      repo,
      AppPreferences(await SharedPreferences.getInstance()),
    );
  });

  tearDown(sl.reset);

  Widget app(Widget home) => BlocProvider.value(
    value: city,
    child: MaterialApp(home: home),
  );

  testWidgets('Cinemas tab lists the cinemas of the saved city', (t) async {
    when(() => repo.cinemas(city: 'Hà Nội')).thenAnswer(
      (_) async => const [
        Cinema(
          id: 1,
          name: 'CineBook Tràng Tiền',
          city: 'Hà Nội',
          address: '1 Tràng Tiền',
        ),
        Cinema(
          id: 2,
          name: 'CineBook Cầu Giấy',
          city: 'Hà Nội',
          address: '99 Xuân Thủy',
        ),
      ],
    );
    await t.pumpWidget(app(const CinemasPage()));
    await t.pumpAndSettle();

    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('CineBook Tràng Tiền'), findsOneWidget);
    expect(find.text('99 Xuân Thủy'), findsOneWidget);
  });

  testWidgets('a cinema schedule shows movies with their time chips', (
    t,
  ) async {
    when(() => repo.schedule(1, any())).thenAnswer(
      (i) async => CinemaSchedule(
        cinema: const Cinema(
          id: 1,
          name: 'CineBook Tràng Tiền',
          city: 'Hà Nội',
          address: '1 Tràng Tiền',
        ),
        date: i.positionalArguments[1] as DateTime,
        movies: [
          MovieSlots(
            movieId: 7,
            title: 'Chợ Đêm',
            ageRating: 'T16',
            durationMin: 116,
            showtimes: [
              slot(1, hourUtc: 2),
              slot(2, hourUtc: 5, bookable: false),
            ],
          ),
        ],
      ),
    );
    await t.pumpWidget(app(const CinemaSchedulePage(cinemaId: 1)));
    await t.pumpAndSettle();

    expect(find.text('CineBook Tràng Tiền'), findsOneWidget);
    expect(find.text('Chợ Đêm'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
  });
}
