import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_toast.dart';

void main() {
  testWidgets('showAppToast 走主题样式（圆角 = cardRadius，floating），无硬编码覆写', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppToast(context, '测试提示'),
              child: const Text('toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('toast'));
    await tester.pump();

    expect(find.text('测试提示'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    // 调用点不应覆写 shape / behavior —— 完全交由主题决定。
    expect(snackBar.shape, isNull);
    expect(snackBar.behavior, isNull);

    // 主题圆角应为 cardRadius（16），而非曾经的硬编码 12。
    final theme = AppTheme.build();
    final shape = theme.snackBarTheme.shape as RoundedRectangleBorder;
    final radius = shape.borderRadius as BorderRadius;
    expect(radius.topLeft.x, AppLayoutConstants.cardRadius);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  });
}
