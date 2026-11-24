import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/tickets/data/ticket_repository_impl.dart';
import 'package:cinebook/features/tickets/data/tickets_api.dart';
import 'package:cinebook/features/tickets/domain/ticket.dart';
import 'package:cinebook/features/tickets/domain/ticket_repository.dart';
import 'package:cinebook/features/tickets/presentation/cubit/tickets_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'ticket_fixtures.dart';

class _Api extends Mock implements TicketsApi {}

class _Repo extends Mock implements TicketRepository {}

void main() {
  final upcoming = [TicketSummary.fromJson(ticketJson())];
  final past = [TicketSummary.fromJson(ticketJson(id: 3, code: 'CBOLD234'))];

  test(
    'the repository sends the tab as UPCOMING / PAST and parses the stub',
    () async {
      final api = _Api();
      when(() => api.mine('PAST')).thenAnswer((_) async => [ticketJson()]);
      when(() => api.detail(7)).thenAnswer((_) async => ticketDetailJson());
      final repo = TicketRepositoryImpl(api);

      final list = await repo.mine(TicketScope.past);
      expect(list.single.seats, ['F7', 'F8']);
      expect(list.single.show.movieTitle, 'Phim Thử');

      final d = await repo.detail(7);
      expect(d.seats.map((s) => s.ticketCode), [
        'TKAAAA222233',
        'TKBBBB222233',
      ]);
      expect(d.combos.single.name, 'Combo Solo');
      expect(d.totalAmount, 289000);
    },
  );

  group('TicketsCubit', () {
    late _Repo repo;
    setUp(() {
      repo = _Repo();
      when(
        () => repo.mine(TicketScope.upcoming),
      ).thenAnswer((_) async => upcoming);
      when(() => repo.mine(TicketScope.past)).thenAnswer((_) async => past);
    });

    blocTest<TicketsCubit, TicketsState>(
      'each tab loads once; switching back uses what was loaded',
      build: () => TicketsCubit(repo),
      act: (c) async {
        await c.load();
        await c.selectTab(TicketScope.past);
        await c.selectTab(TicketScope.upcoming);
      },
      verify: (c) {
        expect(c.state.visible, upcoming);
        expect(c.state.lists[TicketScope.past], past);
        verify(() => repo.mine(TicketScope.upcoming)).called(1);
        verify(() => repo.mine(TicketScope.past)).called(1);
      },
    );

    blocTest<TicketsCubit, TicketsState>(
      'after a payment both tabs reload; sign-out forgets everything',
      build: () => TicketsCubit(repo),
      act: (c) async {
        await c.load();
        await c.selectTab(TicketScope.past);
        await c.refreshAll();
        expect(c.state.lists.keys, [TicketScope.past]);
        c.clear();
      },
      verify: (c) {
        expect(c.state, const TicketsState());
        verify(() => repo.mine(TicketScope.past)).called(2);
      },
    );

    blocTest<TicketsCubit, TicketsState>(
      'a failed first load is shown; a retry recovers',
      build: () => TicketsCubit(repo),
      act: (c) async {
        when(() => repo.mine(TicketScope.upcoming)).thenThrow(
          const ApiFailure(code: ApiFailure.offline, message: 'Mất mạng'),
        );
        await c.load();
        expect(c.state.failure?.code, ApiFailure.offline);
        when(
          () => repo.mine(TicketScope.upcoming),
        ).thenAnswer((_) async => upcoming);
        await c.load();
      },
      verify: (c) {
        expect(c.state.failure, isNull);
        expect(c.state.visible, upcoming);
      },
    );
  });
}
