import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  group('i18n 基础设施', () {
    test('AppLocalizations.delegate 存在且非空', () {
      expect(AppLocalizations.delegate, isNotNull);
      expect(
        AppLocalizations.delegate,
        isA<LocalizationsDelegate<AppLocalizations>>(),
      );
    });

    test('supportedLocales 包含 zh', () {
      final locales = AppLocalizations.supportedLocales;
      expect(locales, isNotEmpty);
      expect(
        locales.any((l) => l.languageCode == 'zh'),
        isTrue,
        reason: 'supportedLocales 必须包含 zh',
      );
    });

    test('localizationsDelegates 列表非空且包含 delegate', () {
      final delegates = AppLocalizations.localizationsDelegates;
      expect(delegates, isNotEmpty);
      expect(
        delegates.contains(AppLocalizations.delegate),
        isTrue,
        reason: 'localizationsDelegates 必须包含 AppLocalizations.delegate',
      );
    });
  });

  group('i18n 运行时字符串', () {
    testWidgets('AppLocalizations.of(context) 在 zh locale 下返回非空', (
      tester,
    ) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n, isNotNull);
    });

    testWidgets('关键字符串可通过 AppLocalizations 获取', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // onboarding 欢迎标题
      expect(l10n.onboardingWelcomeTitle, isNotEmpty);
      expect(l10n.onboardingWelcomeTitle, contains('宝宝'));

      // 首页节奏
      expect(l10n.homeCadence, isNotEmpty);
    });
  });
}
