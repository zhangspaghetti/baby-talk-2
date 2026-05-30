import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_english_phrase.dart';

void main() {
  testWidgets('方案 B AppEnglishPhrase 主显示规格 = Fraunces 32/500/1.2/english', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppEnglishPhrase('One more bite.'),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('One more bite.'));
    final style = textWidget.style!;
    final colors = BabyTalkColors.light();

    expect(style.fontFamily, 'Fraunces', reason: '英文短语只用 Fraunces');
    expect(style.fontSize, 32, reason: '统一 Hero 级 32px（M1）');
    expect(style.fontWeight, FontWeight.w500);
    expect(style.height, 1.2);
    expect(style.color, colors.english, reason: '颜色统一 --english');
  });

  testWidgets('AppEnglishPhrase 透传 maxLines / textAlign / overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppEnglishPhrase(
            'A very long english phrase that should clamp',
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(
      find.text('A very long english phrase that should clamp'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.textAlign, TextAlign.center);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
