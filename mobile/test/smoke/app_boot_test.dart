import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seed content parser rejects malformed payload', () {
    expect(
      () => SeedContentBundle.fromJsonString('{"schemaVersion":1,"spaces":[]}'),
      throwsFormatException,
    );
  });

  test('seed content validator rejects wrong audio asset key', () async {
    final bundle = SeedContentBundle(
      spaces: [
        SeedSpace(
          id: 'daily_care',
          title: '日常照护',
          description: 'desc',
          activities: [
            SeedActivity(
              id: 'bath_time',
              title: '洗澡时间',
              summary: 'summary',
              sceneTag: 'Bath time',
              coachTip: 'tip',
              phrases: [
                SeedPhrase(
                  id: 'bad',
                  step: 1,
                  english: 'Bad',
                  chinese: '坏',
                  pronunciation: 'bad',
                  difficulty: 'starter',
                  audioAsset: 'audio/bad.mp3',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(bundle.validateAssets(rootBundle), throwsFormatException);
  });

  testWidgets('app boot smoke renders safe empty state and loads bundled assets', (
    WidgetTester tester,
  ) async {
    final bootState = await AppBootState.load(rootBundle);

    expect(bootState.isReady, isTrue);
    expect(bootState.content, isNotNull);

    await tester.pumpWidget(BabyTalkApp(bootState: bootState));
    await tester.pumpAndSettle();

    expect(find.text('开始练习'), findsOneWidget);
    expect(find.text('离线种子已就绪'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('recent-result-empty')),
      200,
    );
    expect(find.byKey(const Key('recent-result-empty')), findsOneWidget);

    final phrases = bootState.content!.primaryActivity.phrases;
    for (final phrase in phrases) {
      final audioBytes = await rootBundle.load(phrase.audioAsset);
      expect(audioBytes.lengthInBytes, greaterThan(0));
    }
  });
}
