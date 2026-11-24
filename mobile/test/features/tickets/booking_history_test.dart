import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/auth/domain/auth_repository.dart';
import 'package:cinebook/features/auth/domain/user.dart';
import 'package:cinebook/features/auth/presentation/account_page.dart';
import 'package:cinebook/features/auth/presentation/cubit/account_cubit.dart';
import 'package:cinebook/features/tickets/data/ticket_repository_impl.dart';
import 'package:cinebook/features/tickets/data/tickets_api.dart';
import 'package:cinebook/features/tickets/domain/booking_history.dart';
import 'package:cinebook/features/tickets/domain/ticket_repository.dart';
import 'package:cinebook/features/tickets/presentation/cubit/booking_history_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'ticket_fixtures.dart';

class _Api extends Mock implements TicketsApi {}

class _Repo extends Mock implements TicketRepository {}

class _Auth extends Mock implements AuthRepository {}

Map<String, dynamic> historyJson({
  int id = 7,
  String status = 'PAID',
  String? paidAt = '2026-11-22T05:01:00Z',
}) => {
  'id': id,
  'bookingCode': 'CB${id}AAAAA',
  'status': status,
  'show': showJson,
  'seats': ['F7', 'F8'],
  'totalAmount': 210000,
  'createdAt': '2026-11-22T05:00:00Z',
  'paidAt': paidAt,
};

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  test('the repository parses every status and an unpaid booking', () async {
    final api = _Api();
    when(api.history).thenAnswer(
      (_) async => [
        historyJson(),
        historyJson(id: 6, status: 'CANCELLED', paidAt: null),
        historyJson(id: 5, status: 'EXPIRED', paidAt: null),
        historyJson(id: 4, status: 'HOLDING', paidAt: null),
        historyJson(id: 3, status: 'REFUNDED', paidAt: null),
      ],
    );

    final list = await TicketRepositoryImpl(api).history();
    expect(list.map((b) => b.status), [
      BookingStatus.paid,
      BookingStatus.cancelled,
      BookingStatus.expired,
      BookingStatus.holding,
      BookingStatus.other,
    ]);
    expect(list.first.paidAt, DateTime.utc(2026, 11, 22, 5, 1));
    expect(list[1].paidAt, isNull);
    expect(list[1].seats, ['F7', 'F8']);
    expect(list.first.show.movieTitle, 'Phim Thử');
  });

  group('BookingHistoryCubit', () {
    late _Repo repo;
    final paid = BookingHistoryItem.fromJson(historyJson());
    const offline = ApiFailure(code: ApiFailure.offline, message: 'Mất mạng');

    setUp(() => repo = _Repo());

    blocTest<BookingHistoryCubit, BookingHistoryState>(
      'loads the list',
      build: () {
        when(repo.history).thenAnswer((_) async => [paid]);
        return BookingHistoryCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => [
        const BookingHistoryState(loading: true),
        BookingHistoryState(items: [paid]),
      ],
    );

    blocTest<BookingHistoryCubit, BookingHistoryState>(
      'a failed refresh keeps the list it had; clear forgets it',
      build: () {
        when(repo.history).thenThrow(offline);
        return BookingHistoryCubit(repo);
      },
      seed: () => BookingHistoryState(items: [paid]),
      act: (c) async {
        await c.load();
        c.clear();
      },
      expect: () => [
        BookingHistoryState(items: [paid], loading: true),
        BookingHistoryState(items: [paid], failure: offline),
        const BookingHistoryState(),
      ],
    );
  });

  group('S14 history', () {
    late _Repo repo;
    late _Auth auth;

    setUp(() {
      repo = _Repo();
      auth = _Auth();
      when(auth.me).thenAnswer(
        (_) async => const User(
          id: 1,
          email: 'demo@cinebook.vn',
          fullName: 'Người Thử',
          role: 'CUSTOMER',
        ),
      );
    });

    Future<void> pump(WidgetTester t) async {
      t.view.physicalSize = const Size(400, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(
        initialLocation: '/account',
        routes: [
          GoRoute(
            path: '/account',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => AccountCubit(auth)..load()),
                BlocProvider(create: (_) => BookingHistoryCubit(repo)..load()),
              ],
              child: const AccountView(),
            ),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (_, s) => Text('S13 ${s.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
    }

    testWidgets('shows each booking with its status; a paid one opens S13', (
      t,
    ) async {
      when(repo.history).thenAnswer(
        (_) async => [
          BookingHistoryItem.fromJson(historyJson()),
          BookingHistoryItem.fromJson(
            historyJson(id: 6, status: 'CANCELLED', paidAt: null),
          ),
        ],
      );
      await pump(t);

      expect(find.text('Lịch sử giao dịch'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      expect(find.text('Đã huỷ'), findsOneWidget);
      expect(find.text('Ghế: F7, F8'), findsNWidgets(2));
      expect(find.text('210.000 đ'), findsNWidgets(2));

      // A cancelled booking has no ticket to open.
      await t.tap(find.text('Đã huỷ'));
      await t.pumpAndSettle();
      expect(find.text('Lịch sử giao dịch'), findsOneWidget);

      await t.tap(find.text('Đã thanh toán'));
      await t.pumpAndSettle();
      expect(find.text('S13 7'), findsOneWidget);
    });

    testWidgets('empty and failed history', (t) async {
      when(repo.history).thenAnswer((_) async => []);
      await pump(t);
      expect(find.text('Bạn chưa có giao dịch nào'), findsOneWidget);

      when(repo.history).thenThrow(
        const ApiFailure(code: ApiFailure.offline, message: 'Mất mạng'),
      );
      await t.pumpWidget(const SizedBox());
      await pump(t);
      expect(find.text('Không tải được lịch sử. Mất mạng'), findsOneWidget);

      when(
        repo.history,
      ).thenAnswer((_) async => [BookingHistoryItem.fromJson(historyJson())]);
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('Đã thanh toán'), findsOneWidget);
    });
  });
}
