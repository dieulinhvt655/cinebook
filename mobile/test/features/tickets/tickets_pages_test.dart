import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/tickets/domain/ticket.dart';
import 'package:cinebook/features/tickets/domain/ticket_repository.dart';
import 'package:cinebook/features/tickets/presentation/cubit/ticket_detail_cubit.dart';
import 'package:cinebook/features/tickets/presentation/cubit/tickets_cubit.dart';
import 'package:cinebook/features/tickets/presentation/ticket_detail_page.dart';
import 'package:cinebook/features/tickets/presentation/tickets_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'ticket_fixtures.dart';

class _Repo extends Mock implements TicketRepository {}

void main() {
  late _Repo repo;

  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() => repo = _Repo());

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> pumpList(WidgetTester t) async {
    phone(t);
    final router = GoRouter(
      initialLocation: '/tickets',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('S04')),
        GoRoute(
          path: '/tickets',
          builder: (_, _) => BlocProvider(
            create: (_) => TicketsCubit(repo)..load(),
            child: const TicketsView(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) => Text('S13 ${s.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
  }

  testWidgets('S12 lists ticket cards; tapping one opens S13', (t) async {
    when(
      () => repo.mine(TicketScope.upcoming),
    ).thenAnswer((_) async => [TicketSummary.fromJson(ticketJson())]);
    await pumpList(t);

    expect(find.text('Phim Thử'), findsOneWidget);
    expect(find.text('Rạp Một'), findsOneWidget);
    expect(find.text('Ghế: F7, F8'), findsOneWidget);

    await t.tap(find.text('Phim Thử'));
    await t.pumpAndSettle();
    expect(find.text('S13 7'), findsOneWidget);
  });

  testWidgets(
    'no tickets: "Đặt vé ngay" goes to Home; "Đã xem" has its own list',
    (t) async {
      when(() => repo.mine(TicketScope.upcoming)).thenAnswer((_) async => []);
      when(() => repo.mine(TicketScope.past)).thenAnswer((_) async => []);
      await pumpList(t);

      expect(find.text('Bạn chưa có vé nào'), findsOneWidget);
      await t.tap(find.text('Đã xem'));
      await t.pumpAndSettle();
      expect(find.text('Chưa có vé đã xem'), findsOneWidget);
      expect(find.text('Đặt vé ngay'), findsNothing);

      await t.tap(find.text('Sắp tới'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đặt vé ngay'));
      await t.pumpAndSettle();
      expect(find.text('S04'), findsOneWidget);
    },
  );

  Future<void> pumpDetail(WidgetTester t) async {
    phone(t);
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => TicketDetailCubit(repo, 7)..load(),
          child: const TicketDetailView(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('S13 shows the stub with the signed QR and the booking code', (
    t,
  ) async {
    when(
      () => repo.detail(7),
    ).thenAnswer((_) async => TicketDetail.fromJson(ticketDetailJson()));
    await pumpDetail(t);

    final qr = t.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, 200);
    expect(find.text('CBAB12CD'), findsOneWidget);
    expect(find.text('Phim Thử'), findsOneWidget);
    expect(find.text('F7, F8'), findsOneWidget);
    expect(find.text('Combo Solo × 1'), findsOneWidget);
    expect(find.text('289.000 đ'), findsOneWidget);
    expect(find.text('Đưa mã này cho nhân viên soát vé'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('someone else\'s ticket shows the server message', (t) async {
    when(() => repo.detail(7)).thenThrow(
      const ApiFailure(code: 'NOT_FOUND', message: 'Không tìm thấy vé'),
    );
    await pumpDetail(t);

    expect(find.text('Không tìm thấy vé'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
}
