import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/presentation/widgets/practice_completion_view.dart';
import 'package:mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.build(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('显示「今天完成了」标题', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeCompletionView(spokenCount: 3, onRestart: () {}, onExit: () {}),
      ),
    );
    expect(find.text('今天完成了'), findsOneWidget);
  });

  testWidgets('显示 spokenCount 句数', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeCompletionView(spokenCount: 5, onRestart: () {}, onExit: () {}),
      ),
    );
    expect(find.textContaining('5 句'), findsOneWidget);
  });

  testWidgets('「再来一句」按钮触发 onRestart', (tester) async {
    bool restarted = false;
    await tester.pumpWidget(
      _wrap(
        PracticeCompletionView(
          spokenCount: 1,
          onRestart: () => restarted = true,
          onExit: () {},
        ),
      ),
    );
    await tester.tap(find.text('再来一句'));
    expect(restarted, isTrue);
  });

  testWidgets('「回到场景」按钮触发 onExit', (tester) async {
    bool exited = false;
    await tester.pumpWidget(
      _wrap(
        PracticeCompletionView(
          spokenCount: 1,
          onRestart: () {},
          onExit: () => exited = true,
        ),
      ),
    );
    await tester.tap(find.text('回到场景'));
    expect(exited, isTrue);
  });
}
