import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mini_seed_card.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('MentorBubble a11y', () {
    testWidgets('MentorBubble 包含 Semantics widget with label', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildTestApp(const MentorBubble(message: '你好，欢迎使用 Baby Talk！')),
        );

        expect(
          find.bySemanticsLabel('小禾老师引导消息：你好，欢迎使用 Baby Talk！'),
          findsOneWidget,
          reason: 'MentorBubble 需要本地化最终语义标签',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('MentorBubble trailing content remains accessible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildTestApp(
            const MentorBubble(message: '先看一条提示。', trailing: Text('文字优先回复说明')),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp('文字优先回复说明')),
          findsOneWidget,
          reason: 'MentorBubble trailing 内容不能被共享语义 wrapper 静音',
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('MiniSeedCard a11y', () {
    testWidgets('MiniSeedCard 包含 Semantics widget with label', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildTestApp(const MiniSeedCard(english: 'Hello', chinese: '你好')),
        );

        expect(
          find.bySemanticsLabel('第一颗种子：Hello'),
          findsOneWidget,
          reason: 'MiniSeedCard 需要本地化 Semantics label',
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('PhraseCard a11y', () {
    testWidgets('PhraseCard 包含 "English phrase:" Semantics label', (
      tester,
    ) async {
      const phrase = PracticePhrase(
        spaceId: 'test-space',
        activityId: 'test-activity',
        phraseId: 'test-1',
        english: 'Good morning',
        chinese: '早上好',
        pronunciation: '/ɡʊd ˈmɔːrnɪŋ/',
        step: 1,
        difficulty: 'easy',
        audioAsset: 'test.mp3',
      );

      await tester.pumpWidget(
        buildTestApp(
          PhraseCard(
            phrase: phrase,
            isActive: false,
            isCompleted: false,
            playbackStatus: PracticePlaybackStatus.idle,
            saveStatus: PracticeSaveStatus.idle,
            playbackMessage: null,
            saveMessage: null,
            canPlay: false,
            canSubmitReaction: false,
            onPlay: null,
            onReactionSelected: null,
          ),
        ),
      );

      final semanticsWidget = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains('English phrase:') ?? false),
      );
      expect(
        semanticsWidget,
        findsOneWidget,
        reason: 'PhraseCard 需要包含 "English phrase:" 的 Semantics label',
      );
    });

    testWidgets('Active PhraseCard 播放按钮有 "播放发音" Semantics', (tester) async {
      const phrase = PracticePhrase(
        spaceId: 'test-space',
        activityId: 'test-activity',
        phraseId: 'test-2',
        english: 'Hello',
        chinese: '你好',
        pronunciation: '/həˈloʊ/',
        step: 1,
        difficulty: 'easy',
        audioAsset: 'test.mp3',
      );

      await tester.pumpWidget(
        buildTestApp(
          PhraseCard(
            phrase: phrase,
            isActive: true,
            isCompleted: false,
            playbackStatus: PracticePlaybackStatus.idle,
            saveStatus: PracticeSaveStatus.idle,
            playbackMessage: null,
            saveMessage: null,
            canPlay: true,
            canSubmitReaction: false,
            onPlay: () {},
            onReactionSelected: null,
          ),
        ),
      );

      final playSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '播放发音',
      );
      expect(
        playSemantics,
        findsOneWidget,
        reason: '播放按钮需要 "播放发音" Semantics label',
      );
    });
  });

  group('Touch target 尺寸', () {
    testWidgets('播放按钮容器 >= 48x48', (tester) async {
      const phrase = PracticePhrase(
        spaceId: 'test-space',
        activityId: 'test-activity',
        phraseId: 'touch-1',
        english: 'Hi',
        chinese: '嗨',
        pronunciation: '/haɪ/',
        step: 1,
        difficulty: 'easy',
        audioAsset: 'test.mp3',
      );

      await tester.pumpWidget(
        buildTestApp(
          PhraseCard(
            phrase: phrase,
            isActive: true,
            isCompleted: false,
            playbackStatus: PracticePlaybackStatus.idle,
            saveStatus: PracticeSaveStatus.idle,
            playbackMessage: null,
            saveMessage: null,
            canPlay: true,
            canSubmitReaction: false,
            onPlay: () {},
            onReactionSelected: null,
          ),
        ),
      );

      // 播放按钮包裹在 72x72 SizedBox 中，通过 ElevatedButton key 查找
      final playButtonFinder = find.byKey(const Key('play-touch-1'));
      expect(playButtonFinder, findsOneWidget);
      final size = tester.getSize(playButtonFinder);
      expect(size.width, greaterThanOrEqualTo(48), reason: '播放按钮宽度必须 >= 48');
      expect(size.height, greaterThanOrEqualTo(48), reason: '播放按钮高度必须 >= 48');
    });
  });
}
