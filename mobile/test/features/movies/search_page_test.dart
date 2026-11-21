import 'package:cinebook/app/di.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/recent_searches.dart';
import 'package:cinebook/features/movies/presentation/search_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements MovieRepository {}

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    sl
      ..registerSingleton<MovieRepository>(repo)
      ..registerSingleton(RecentSearches());
  });

  tearDown(sl.reset);

  testWidgets('no match shows the empty state with the query', (t) async {
    when(
      () => repo.movies(query: any(named: 'query')),
    ).thenAnswer((_) async => []);
    await t.pumpWidget(const MaterialApp(home: SearchPage()));
    await t.enterText(find.byType(TextField), 'xyz');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();

    expect(find.text('Không tìm thấy phim cho “xyz”'), findsOneWidget);
    verify(() => repo.movies(query: 'xyz')).called(1);
  });
}
