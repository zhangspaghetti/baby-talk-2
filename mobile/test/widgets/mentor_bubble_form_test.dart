import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_mentor_bubble.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// 形态契约测试 —— 锁定两个导师气泡变体的「收敛目标态」（方案 B，2026-05-29）。
///
/// 步骤 2 形态收敛后，两变体共享统一外壳：28×28 圆角矩形(r12) 暖色渐变头像、
/// 气泡 r16 对称圆角、`warmShadowSm` 阴影、无边框、内边距 12/16。任何偏离都视为
/// 视觉回归。详见
/// `docs/superpowers/specs/2026-05-29-component-spec-tech-review.md` 第五节。
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

  List<({Container widget, BoxDecoration decoration})> decoratedContainers(
    WidgetTester tester,
    Finder root,
  ) {
    return tester
        .widgetList<Container>(
          find.descendant(of: root, matching: find.byType(Container)),
        )
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => (widget: c, decoration: c.decoration as BoxDecoration))
        .toList();
  }

  void expectSharedAvatar(
    ({Container widget, BoxDecoration decoration}) avatar,
  ) {
    expect(
      avatar.widget.constraints,
      const BoxConstraints.tightFor(width: 28, height: 28),
      reason: '目标态头像统一为 28×28（MentorAvatar.Inline）',
    );
    expect(avatar.decoration.gradient, isNotNull, reason: '头像为暖色渐变');
    expect(
      avatar.decoration.borderRadius,
      BorderRadius.circular(12),
      reason: '头像为圆角矩形 r12，非圆形',
    );
    expect(
      avatar.decoration.shape,
      BoxShape.rectangle,
      reason: '头像不再使用 BoxShape.circle',
    );
  }

  void expectSharedBubble(
    ({Container widget, BoxDecoration decoration}) bubble,
  ) {
    expect(
      bubble.decoration.borderRadius,
      BorderRadius.circular(16),
      reason: '目标态气泡统一为对称 r16（--radius-md）',
    );
    expect(bubble.decoration.border, isNull, reason: '目标态气泡无边框');
    expect(
      bubble.decoration.boxShadow,
      isNotNull,
      reason: '目标态气泡带 shadow-sm',
    );
    expect(
      bubble.decoration.boxShadow,
      isNotEmpty,
      reason: '目标态气泡带 shadow-sm',
    );
    expect(
      bubble.widget.padding,
      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      reason: '目标态内边距 12/16',
    );
  }

  group('AppMentorBubble 形态契约（收敛目标态）', () {
    testWidgets('头像为 28x28 圆角矩形渐变', (tester) async {
      await tester.pumpWidget(
        buildApp(const AppMentorBubble(message: '你好')),
      );

      final containers =
          decoratedContainers(tester, find.byType(AppMentorBubble));
      final avatar = containers.firstWhere(
        (c) => c.decoration.gradient != null,
        orElse: () => throw StateError('未找到渐变头像容器'),
      );

      expectSharedAvatar(avatar);
    });

    testWidgets('气泡为对称 r16、有阴影、无边框', (tester) async {
      await tester.pumpWidget(
        buildApp(const AppMentorBubble(message: '你好')),
      );

      final containers =
          decoratedContainers(tester, find.byType(AppMentorBubble));
      final bubble = containers.firstWhere(
        (c) =>
            c.decoration.gradient == null &&
            c.decoration.borderRadius != null,
        orElse: () => throw StateError('未找到气泡容器'),
      );

      expectSharedBubble(bubble);
    });
  });

  group('HomeBMentorBubble 形态契约（收敛目标态）', () {
    testWidgets('头像为 28x28 圆角矩形渐变', (tester) async {
      await tester.pumpWidget(
        buildApp(const HomeBMentorBubble(message: '建议内容')),
      );

      final containers =
          decoratedContainers(tester, find.byType(HomeBMentorBubble));
      final avatar = containers.firstWhere(
        (c) => c.decoration.gradient != null,
        orElse: () => throw StateError('未找到渐变头像容器'),
      );

      expectSharedAvatar(avatar);
    });

    testWidgets('容器为对称 r16、有阴影、无边框', (tester) async {
      await tester.pumpWidget(
        buildApp(const HomeBMentorBubble(message: '建议内容')),
      );

      final outer = tester.widget<Container>(
        find.byKey(const Key('home-b-mentor-bubble')),
      );

      expectSharedBubble(
        (widget: outer, decoration: outer.decoration as BoxDecoration),
      );
    });
  });
}
