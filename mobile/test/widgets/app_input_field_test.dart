import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_input_field.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// 形态契约测试 —— 锁定 `AppInputField` 的收敛目标态（规范 §2.13，2026-05-31 抽取）。
///
/// 目标态：圆角 8（`AppLayoutConstants.smallRadius` / `--radius-sm`）、内边距 12/16、
/// 字号 16/w400、standard 用 `bgSurface`、search 用 `bgSunken` + 前置搜索图标 +
/// 有文本时显示清除按钮。任何偏离视为视觉回归。
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  InputDecoration decorationOf(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).decoration!;
  }

  group('AppInputField 形态契约（收敛目标态）', () {
    testWidgets('standard 变体：r8 圆角、bgSurface 背景、12/16 内边距', (tester) async {
      await tester.pumpWidget(buildApp(const AppInputField(hintText: '请输入')));

      final decoration = decorationOf(tester);
      final border = decoration.enabledBorder as OutlineInputBorder;
      expect(
        border.borderRadius,
        BorderRadius.circular(AppLayoutConstants.smallRadius),
        reason: '输入框圆角统一为 r8（--radius-sm）',
      );
      expect(decoration.filled, isTrue);
      expect(
        decoration.contentPadding,
        const EdgeInsets.symmetric(
          horizontal: AppLayoutConstants.spacingMd,
          vertical: AppLayoutConstants.spacingSm,
        ),
        reason: '内边距 12/16',
      );
    });

    testWidgets('standard 变体使用 bgSurface 填充色', (tester) async {
      await tester.pumpWidget(buildApp(const AppInputField(hintText: '请输入')));

      final context = tester.element(find.byType(AppInputField));
      expect(decorationOf(tester).fillColor, context.appColors.bgSurface);
    });

    testWidgets('search 变体：bgSunken 背景 + 前置搜索图标', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const AppInputField(
            variant: AppInputFieldVariant.search,
            hintText: '搜索',
          ),
        ),
      );

      final context = tester.element(find.byType(AppInputField));
      expect(decorationOf(tester).fillColor, context.appColors.bgSunken);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('search 变体：有文本且提供 onClear 时显示清除按钮', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          AppInputField(
            variant: AppInputFieldVariant.search,
            controller: controller,
            onClear: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('search 变体：输入变化时清除按钮随 empty->text->empty 自动切换', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          AppInputField(
            variant: AppInputFieldVariant.search,
            controller: controller,
            onClear: controller.clear,
            fieldKey: const Key('search-field'),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byKey(const Key('search-field')), 'hello');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), '');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('search 变体：无 onClear 时不显示清除按钮', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          AppInputField(
            variant: AppInputFieldVariant.search,
            controller: controller,
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('提供 semanticsLabel 时包裹 Semantics(textField)', (tester) async {
      await tester.pumpWidget(
        buildApp(const AppInputField(hintText: '请输入', semanticsLabel: '手机号')),
      );

      expect(
        find.bySemanticsLabel('手机号'),
        findsOneWidget,
        reason: '语义标签应可被无障碍工具读取',
      );
    });
  });
}
