import 'package:cinebook/app/di.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/auth/domain/auth_repository.dart';
import 'package:cinebook/features/auth/presentation/login_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AuthRepository {}

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    sl.registerSingleton<AuthRepository>(repo);
  });

  tearDown(sl.reset);

  Future<void> pump(WidgetTester t) =>
      t.pumpWidget(const MaterialApp(home: LoginPage()));

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('empty fields show messages and send nothing (BR-04.1)', (
    t,
  ) async {
    await pump(t);
    await t.tap(find.text('Đăng nhập'));
    await t.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    verifyNever(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets(
    'wrong credentials: generic message, email kept, password cleared',
    (t) async {
      when(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ApiFailure(
          code: 'INVALID_CREDENTIALS',
          message: 'Email hoặc mật khẩu không chính xác',
          status: 401,
        ),
      );
      await pump(t);
      await t.enterText(field('Email'), 'demo@cinebook.dev');
      await t.enterText(field('Mật khẩu'), 'wrong password');
      await t.tap(find.text('Đăng nhập'));
      await t.pumpAndSettle();

      expect(find.text('Email hoặc mật khẩu không chính xác'), findsOneWidget);
      expect(find.text('demo@cinebook.dev'), findsOneWidget);
      expect(find.text('wrong password'), findsNothing);
    },
  );

  testWidgets('offline keeps both fields and offers "Thử lại" (BR-04.3)', (
    t,
  ) async {
    when(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const ApiFailure(
        code: ApiFailure.offline,
        message: 'Không có kết nối mạng, vui lòng kiểm tra và thử lại',
      ),
    );
    await pump(t);
    await t.enterText(field('Email'), 'demo@cinebook.dev');
    await t.enterText(field('Mật khẩu'), 'Demo@1234');
    await t.tap(find.text('Đăng nhập'));
    await t.pumpAndSettle();

    expect(
      find.text('Không có kết nối mạng, vui lòng kiểm tra và thử lại'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Demo@1234'), findsOneWidget);
  });

  testWidgets('password is hidden by default and can be shown (BR-02.6)', (
    t,
  ) async {
    await pump(t);
    EditableText password() => t.widget<EditableText>(
      find.descendant(
        of: field('Mật khẩu'),
        matching: find.byType(EditableText),
      ),
    );

    expect(password().obscureText, isTrue);
    await t.tap(find.byTooltip('Hiện mật khẩu'));
    await t.pump();
    expect(password().obscureText, isFalse);
  });
}
