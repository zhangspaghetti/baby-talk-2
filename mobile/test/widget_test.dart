import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('default widget entry delegates to bootable app shell', (
    WidgetTester tester,
  ) async {
    final bootState = await AppBootState.load(rootBundle);
    await tester.pumpWidget(BabyTalkApp(bootState: bootState));
    await tester.pumpAndSettle();

    expect(find.text('开始练习'), findsOneWidget);
  });
}
