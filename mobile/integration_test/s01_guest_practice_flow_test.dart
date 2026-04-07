import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest user can boot app and enter bath time practice shell', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('开始练习'), findsOneWidget);
    await tester.tap(find.text('开始练习'));
    await tester.pumpAndSettle();

    expect(find.text('Warm water.'), findsOneWidget);
    expect(find.text('Splash, splash!'), findsOneWidget);
    expect(find.text('All clean.'), findsOneWidget);
  });
}
