import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_segment_tab.dart';

void main() {
  Future<void> pumpTab(
    WidgetTester tester, {
    required bool isSelected,
    required VoidCallback onTap,
    String? semanticsLabel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: AppSegmentTab(
                key: const Key('segment-tab-under-test'),
                label: '花园',
                isSelected: isSelected,
                onTap: onTap,
                semanticsLabel: semanticsLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('未选中态：透明底、textMuted、w500', (tester) async {
    await pumpTab(tester, isSelected: false, onTap: () {});
    final colors = BabyTalkColors.light();

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('segment-tab-under-test')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(decoration.boxShadow, isNull, reason: '未选中态无阴影');

    final text = tester.widget<Text>(find.text('花园'));
    expect(text.style?.color, colors.textMuted);
    expect(text.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('选中态：bgSurface 底、warmShadowSm 阴影、textPrimary、w700', (tester) async {
    await pumpTab(tester, isSelected: true, onTap: () {});
    final colors = BabyTalkColors.light();

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('segment-tab-under-test')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.boxShadow, colors.warmShadowSm);

    final text = tester.widget<Text>(find.text('花园'));
    expect(text.style?.color, colors.textPrimary);
    expect(text.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('点击触发 onTap', (tester) async {
    var tapped = 0;
    await pumpTab(tester, isSelected: false, onTap: () => tapped++);
    await tester.tap(find.byKey(const Key('segment-tab-under-test')));
    expect(tapped, 1);
  });

  testWidgets('最小触控高度 minTouchTarget', (tester) async {
    await pumpTab(tester, isSelected: false, onTap: () {});
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('segment-tab-under-test')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      container.constraints?.minHeight,
      AppLayoutConstants.minTouchTarget,
    );
  });

  testWidgets('携带 button + selected 语义', (tester) async {
    await pumpTab(tester, isSelected: true, onTap: () {});
    final semantics = tester.getSemantics(
      find.byKey(const Key('segment-tab-under-test')),
    );
    expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
  });

  testWidgets('semanticsLabel 覆盖播报标签', (tester) async {
    await pumpTab(
      tester,
      isSelected: false,
      onTap: () {},
      semanticsLabel: '切换到花园视图',
    );
    final semantics = tester.getSemantics(
      find.byKey(const Key('segment-tab-under-test')),
    );
    expect(semantics.label, contains('切换到花园视图'));
  });
}
