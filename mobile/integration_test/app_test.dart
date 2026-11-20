import 'package:cinebook/app/app.dart';
import 'package:cinebook/app/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install lands on the login screen', (tester) async {
    await configureDependencies();
    await tester.pumpWidget(const CineBookApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Đăng nhập'), findsWidgets);
  });
}
