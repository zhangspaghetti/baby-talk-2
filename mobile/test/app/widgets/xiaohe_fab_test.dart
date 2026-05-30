import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/xiaohe_fab.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget fab) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(),
      home: Scaffold(floatingActionButton: fab),
    );
  }

  testWidgets('XiaoheFab 标准形态 = auto_awesome 图标 + mentorName tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(const XiaoheFab(launcher: 'shell_fab', surface: 'home')),
    );

    final l = AppLocalizations.of(
      tester.element(find.byType(XiaoheFab)),
    )!;

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.tooltip, l.mentorName);
    expect(fab.mini, isFalse);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('XiaoheFab small 形态使用紧凑 FAB', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const XiaoheFab(launcher: 'home_fab', surface: 'standalone_home', small: true),
      ),
    );

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.mini, isTrue);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
