import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

void main() {
  group('PracticeScene', () {
    test('allScenes contains 6 scenes', () {
      expect(PracticeSceneX.allScenes.length, 6);
    });

    test('label returns Chinese name for each scene', () {
      expect(PracticeScene.feeding.label, '喂饭');
      expect(PracticeScene.drinking.label, '喝水');
      expect(PracticeScene.diaper.label, '换尿布');
      expect(PracticeScene.bath.label, '洗澡');
      expect(PracticeScene.bedtime.label, '睡前');
      expect(PracticeScene.outing.label, '出门');
    });

    test('mentorBubbleCopy returns copy for each scene', () {
      for (final scene in PracticeSceneX.allScenes) {
        expect(scene.mentorBubbleCopy.isNotEmpty, true);
        expect(scene.mentorBubbleCopy.length <= 15, true);
      }
    });

    test('completionTitle returns title for each scene', () {
      for (final scene in PracticeSceneX.allScenes) {
        expect(scene.completionTitle.isNotEmpty, true);
      }
    });

    test('defaultSceneForHour returns correct scene for time ranges', () {
      expect(PracticeSceneX.defaultSceneForHour(8), PracticeScene.feeding);
      expect(PracticeSceneX.defaultSceneForHour(10), PracticeScene.drinking);
      expect(PracticeSceneX.defaultSceneForHour(13), PracticeScene.diaper);
      expect(PracticeSceneX.defaultSceneForHour(16), PracticeScene.bath);
      expect(PracticeSceneX.defaultSceneForHour(19), PracticeScene.bedtime);
      expect(PracticeSceneX.defaultSceneForHour(3), PracticeScene.outing);
      expect(PracticeSceneX.defaultSceneForHour(22), PracticeScene.outing);
    });
  });
}
