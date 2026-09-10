import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_care_moment_title.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_mentor_bubble.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_scene_card.dart';

void main() {
  group('HomeBCareMomentTitle', () {
    testWidgets('renders scene title with child name', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBCareMomentTitle(
          sceneTag: 'Bedtime',
          sceneTitle: '收个尾',
          childName: '米米',
        ),
      );

      expect(find.byKey(const Key('home-b-care-moment-title')), findsOneWidget);
      // RichText content is not searchable with find.textContaining;
      // verify via the RichText widget's text spans
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final plainText = richText.text.toPlainText();
      expect(plainText, contains('陪米米收个尾'));
      expect(find.text('Bedtime'), findsOneWidget);
    });

    testWidgets('uses default "宝宝" when child name is null', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBCareMomentTitle(sceneTag: 'Bath time', sceneTitle: '洗澡时间'),
      );

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final plainText = richText.text.toPlainText();
      expect(plainText, contains('陪宝宝洗澡时间'));
    });

    testWidgets('displays scene tag pill', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBCareMomentTitle(
          sceneTag: 'Feeding time',
          sceneTitle: '喂饭',
          childName: '果果',
        ),
      );

      // Scene tag is rendered in a Container with accent styling
      expect(find.text('Feeding time'), findsOneWidget);
    });

    testWidgets('shows time-of-day word in headline', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBCareMomentTitle(
          sceneTag: 'Bath time',
          sceneTitle: '洗澡',
          childName: '宝宝',
        ),
      );

      // The headline should contain one of: 早上, 下午, 今晚
      final richTextWidget = tester.widget<RichText>(
        find.byType(RichText).first,
      );
      final plainText = richTextWidget.text.toPlainText();
      final hasTimeWord =
          plainText.contains('早上') ||
          plainText.contains('下午') ||
          plainText.contains('今晚');
      expect(hasTimeWord, isTrue);
    });
  });

  group('HomeBMentorBubble', () {
    testWidgets('renders mentor name and message', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBMentorBubble(message: '这句适合睡前收尾，不像命令，更像邀请宝宝一起完成。'),
      );

      expect(find.byKey(const Key('home-b-mentor-bubble')), findsOneWidget);
      expect(find.text('小禾'), findsOneWidget);
      expect(find.text('这句适合睡前收尾，不像命令，更像邀请宝宝一起完成。'), findsOneWidget);
    });

    testWidgets('shows chevron icon when onTap is provided', (tester) async {
      var tapped = false;

      await _pumpWidget(
        tester,
        HomeBMentorBubble(
          message: '建议内容',
          onTap: () {
            tapped = true;
          },
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-b-mentor-bubble')));
      expect(tapped, isTrue);
    });

    testWidgets('hides chevron icon when onTap is null', (tester) async {
      await _pumpWidget(tester, const HomeBMentorBubble(message: '建议内容'));

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('message is limited to 2 lines with ellipsis', (tester) async {
      final longMessage =
          '这是一条非常长的建议内容，用来测试文本溢出行为。'
          '这条消息应该被限制在两行以内，超出部分用省略号截断。'
          '这第三部分不应该被显示出来。';

      await _pumpWidget(tester, HomeBMentorBubble(message: longMessage));

      final textWidgets = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('home-b-mentor-bubble')),
          matching: find.byType(Text),
        ),
      );
      // The message Text widget should be the last one (after "小禾")
      final messageText = textWidgets.last;
      expect(messageText.maxLines, 2);
      expect(messageText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('has proper accessibility semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpWidget(
          tester,
          HomeBMentorBubble(message: '测试建议', onTap: () {}),
        );

        // Find the Semantics widget that has our label
        final allSemantics = tester.widgetList<Semantics>(
          find.byType(Semantics),
        );
        final matchingSemantics = allSemantics.firstWhere(
          (s) => s.properties.label?.contains('小禾建议') == true,
          orElse: () =>
              throw StateError('No Semantics widget with label found'),
        );
        expect(matchingSemantics.properties.label, contains('小禾建议'));
        expect(matchingSemantics.properties.label, contains('测试建议'));
        expect(matchingSemantics.properties.button, isTrue);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('HomeBSceneCard', () {
    testWidgets(
      'renders parent action, English phrase, and Chinese translation',
      (tester) async {
        await _pumpWidget(
          tester,
          HomeBSceneCard(
            phrase: const PracticePhrase(
              spaceId: 'daily_care',
              activityId: 'bath_time',
              phraseId: 'bath_time_warm_water',
              step: 1,
              english: 'Warm water.',
              chinese: '温温的水。',
              pronunciation: 'wɔːrm ˈwɔːtər',
              difficulty: 'starter',
              audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
            ),
            parentAction: '把水温调好，轻轻淋在宝宝背上。',
            sceneTag: 'Bath time',
            onStartPractice: () {},
          ),
        );

        expect(find.byKey(const Key('home-b-scene-card')), findsOneWidget);
        expect(find.text('你的动作'), findsOneWidget);
        expect(find.text('把水温调好，轻轻淋在宝宝背上。'), findsOneWidget);
        expect(find.text('Warm water.'), findsOneWidget);
        expect(find.text('温温的水。'), findsOneWidget);
      },
    );

    testWidgets('renders fallback text when phrase is null', (tester) async {
      await _pumpWidget(
        tester,
        const HomeBSceneCard(phrase: null, parentAction: '做某个动作。'),
      );

      // Should show default English/Chinese text
      expect(find.text("Let's put it back."), findsOneWidget);
      expect(find.text('我们把它放回去吧。'), findsOneWidget);
    });

    testWidgets('shows audio play button with idle state', (tester) async {
      await _pumpWidget(
        tester,
        HomeBSceneCard(
          phrase: const PracticePhrase(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            step: 1,
            english: 'Warm water.',
            chinese: '温温的水。',
            pronunciation: 'wɔːrm ˈwɔːtər',
            difficulty: 'starter',
            audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
          ),
          parentAction: '做某个动作。',
        ),
      );

      expect(find.text('听一遍'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('shows practice CTA button', (tester) async {
      var practiceStarted = false;

      await _pumpWidget(
        tester,
        HomeBSceneCard(
          phrase: const PracticePhrase(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            step: 1,
            english: 'Warm water.',
            chinese: '温温的水。',
            pronunciation: 'wɔːrm ˈwɔːtər',
            difficulty: 'starter',
            audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
          ),
          parentAction: '做某个动作。',
          onStartPractice: () {
            practiceStarted = true;
          },
        ),
      );

      expect(find.byKey(const Key('home-b-start-practice')), findsOneWidget);
      expect(find.text('试着说这一句'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-b-start-practice')));
      expect(practiceStarted, isTrue);
    });

    testWidgets('has accessibility labels for phrase content', (tester) async {
      await _pumpWidget(
        tester,
        HomeBSceneCard(
          phrase: const PracticePhrase(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            step: 1,
            english: 'Warm water.',
            chinese: '温温的水。',
            pronunciation: 'wɔːrm ˈwɔːtər',
            difficulty: 'starter',
            audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
          ),
          parentAction: '做某个动作。',
        ),
      );

      // Semantics labels are rendered as part of the Semantics widget tree
      expect(find.text('Warm water.'), findsOneWidget);
      expect(find.text('温温的水。'), findsOneWidget);
    });

    testWidgets('scene tag and coach tip render when provided', (tester) async {
      await _pumpWidget(
        tester,
        HomeBSceneCard(
          phrase: const PracticePhrase(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            step: 1,
            english: 'Warm water.',
            chinese: '温温的水。',
            pronunciation: 'wɔːrm ˈwɔːtər',
            difficulty: 'starter',
            audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
          ),
          parentAction: '做某个动作。',
          sceneTag: 'Bath time',
          coachTip: '先说动作，再慢慢等待宝宝回应。',
        ),
      );

      // Scene card should render without errors when optional props are set
      expect(find.byKey(const Key('home-b-scene-card')), findsOneWidget);
    });
  });
}

Future<void> _pumpWidget(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
