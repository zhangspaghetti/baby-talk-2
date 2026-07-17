import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_scene_pill.dart';

void main() {
  Future<void> pumpPill(
    WidgetTester tester, {
    required bool isSelected,
    required VoidCallback onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Center(
            child: AppScenePill(
              key: const Key('scene-pill-under-test'),
              label: '吃饭',
              isSelected: isSelected,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('未选中态：bgSunken 底、无边框、textSecondary 文字', (tester) async {
    await pumpPill(tester, isSelected: false, onTap: () {});
    final colors = BabyTalkColors.light();

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('scene-pill-under-test')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, colors.bgSunken);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('scene-pill-under-test')),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNull, reason: '未选中态无边框');

    final text = tester.widget<Text>(find.text('吃饭'));
    expect(text.style?.color, colors.textSecondary);
    expect(text.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('选中态：accent 底、accentDark 1.5px 边框、白色文字', (tester) async {
    await pumpPill(tester, isSelected: true, onTap: () {});
    final colors = BabyTalkColors.light();

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('scene-pill-under-test')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, colors.accent);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('scene-pill-under-test')),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.color, colors.accentDark);
    expect(border.top.width, 1.5);

    final text = tester.widget<Text>(find.text('吃饭'));
    expect(text.style?.color, Colors.white);
  });

  testWidgets('点击触发 onTap 回调', (tester) async {
    var tapped = 0;
    await pumpPill(tester, isSelected: false, onTap: () => tapped++);
    await tester.tap(find.byKey(const Key('scene-pill-under-test')));
    expect(tapped, 1);
  });

  testWidgets('最小触控高度 44px', (tester) async {
    await pumpPill(tester, isSelected: false, onTap: () {});
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('scene-pill-under-test')),
        matching: find.byType(Container),
      ),
    );
    expect(container.constraints?.minHeight, 44);
    expect(
      container.padding,
      const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingMd,
        vertical: AppLayoutConstants.spacingXs,
      ),
    );
  });

  testWidgets('携带 Semantics 选中状态语义', (tester) async {
    await pumpPill(tester, isSelected: true, onTap: () {});
    final semantics = tester.getSemantics(
      find.byKey(const Key('scene-pill-under-test')),
    );
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);
  });
}
