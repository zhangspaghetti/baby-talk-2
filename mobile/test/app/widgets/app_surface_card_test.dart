import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester, Key key) {
    final container = tester.widget<Container>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(Container))
          .first,
    );
    return container.decoration as BoxDecoration;
  }

  testWidgets('方案 B AppSurfaceCard 默认收敛至规范目标态（r16/无边框/sm）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppSurfaceCard(
            key: Key('surface-card-under-test'),
            child: Text('Shared surface'),
          ),
        ),
      ),
    );

    final card = find.byKey(const Key('surface-card-under-test'));
    final container = tester.widget<Container>(
      find.descendant(of: card, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    final borderRadius = decoration.borderRadius as BorderRadius;
    final colors = BabyTalkColors.light();

    expect(
      container.constraints,
      const BoxConstraints.tightFor(width: double.infinity),
    );
    expect(
      container.padding,
      const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingLg, // 20
        vertical: AppLayoutConstants.spacingXl, // 24
      ),
      reason: '目标态内边距 20 horizontal / 24 vertical',
    );
    expect(decoration.color, colors.bgSurface);
    expect(
      borderRadius.topLeft.x,
      AppLayoutConstants.cardRadius, // 16
      reason: '目标态圆角 r16（--radius-md）',
    );
    expect(decoration.border, isNull, reason: '目标态默认无边框');
    expect(
      decoration.boxShadow,
      colors.warmShadowSm,
      reason: 'standard 变体 = shadow-sm',
    );
    expect(find.text('Shared surface'), findsOneWidget);
  });

  testWidgets('elevated 变体使用 shadow-md', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppSurfaceCard(
            key: Key('elevated-card'),
            variant: AppSurfaceCardVariant.elevated,
            child: Text('Elevated'),
          ),
        ),
      ),
    );

    expect(
      decorationOf(tester, const Key('elevated-card')).boxShadow,
      BabyTalkColors.light().warmShadowMd,
    );
  });

  testWidgets('borderless 变体无阴影无边框', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppSurfaceCard(
            key: Key('borderless-card'),
            variant: AppSurfaceCardVariant.borderless,
            child: Text('Borderless'),
          ),
        ),
      ),
    );

    final decoration = decorationOf(tester, const Key('borderless-card'));
    expect(decoration.boxShadow, isEmpty);
    expect(decoration.border, isNull);
  });

  testWidgets('裸参数向后兼容：borderColor 绘制边框、boxShadow 覆盖变体', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppSurfaceCard(
            key: Key('legacy-card'),
            borderColor: Color(0xFFD8CFC8),
            boxShadow: [],
            child: Text('Legacy'),
          ),
        ),
      ),
    );

    final decoration = decorationOf(tester, const Key('legacy-card'));
    expect(decoration.border, Border.all(color: const Color(0xFFD8CFC8)));
    expect(decoration.boxShadow, isEmpty);
  });
}
