import 'dart:math';

import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

class ScenePhrase {
  const ScenePhrase({
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.scene,
  });

  final String phraseId;
  final String english;
  final String chinese;
  final PracticeScene scene;
}

class ScenePhraseService {
  ScenePhraseService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static final _phraseBank = <PracticeScene, List<ScenePhrase>>{
    PracticeScene.feeding: [
      const ScenePhrase(phraseId: 'feed_1', english: 'Are you hungry?', chinese: '你饿了吗？', scene: PracticeScene.feeding),
      const ScenePhrase(phraseId: 'feed_2', english: 'Yummy food!', chinese: '好吃的食物！', scene: PracticeScene.feeding),
      const ScenePhrase(phraseId: 'feed_3', english: 'Let\'s eat together.', chinese: '我们一起吃吧。', scene: PracticeScene.feeding),
      const ScenePhrase(phraseId: 'feed_4', english: 'One more bite.', chinese: '再吃一口。', scene: PracticeScene.feeding),
    ],
    PracticeScene.drinking: [
      const ScenePhrase(phraseId: 'drink_1', english: 'Do you want some water?', chinese: '你想喝水吗？', scene: PracticeScene.drinking),
      const ScenePhrase(phraseId: 'drink_2', english: 'Here is your cup.', chinese: '你的杯子在这。', scene: PracticeScene.drinking),
      const ScenePhrase(phraseId: 'drink_3', english: 'Drink some water.', chinese: '喝点水吧。', scene: PracticeScene.drinking),
    ],
    PracticeScene.diaper: [
      const ScenePhrase(phraseId: 'diaper_1', english: 'Let\'s change your diaper.', chinese: '我们换尿布吧。', scene: PracticeScene.diaper),
      const ScenePhrase(phraseId: 'diaper_2', english: 'All clean now!', chinese: '现在干净啦！', scene: PracticeScene.diaper),
      const ScenePhrase(phraseId: 'diaper_3', english: 'You feel better now.', chinese: '你现在舒服了。', scene: PracticeScene.diaper),
    ],
    PracticeScene.bath: [
      const ScenePhrase(phraseId: 'bath_1', english: 'Bath time!', chinese: '洗澡时间到！', scene: PracticeScene.bath),
      const ScenePhrase(phraseId: 'bath_2', english: 'The water is warm.', chinese: '水是暖的。', scene: PracticeScene.bath),
      const ScenePhrase(phraseId: 'bath_3', english: 'Splash splash!', chinese: '哗啦哗啦！', scene: PracticeScene.bath),
      const ScenePhrase(phraseId: 'bath_4', english: 'Let\'s wash your hands.', chinese: '我们洗手吧。', scene: PracticeScene.bath),
    ],
    PracticeScene.bedtime: [
      const ScenePhrase(phraseId: 'bed_1', english: 'Time for bed.', chinese: '该睡觉了。', scene: PracticeScene.bedtime),
      const ScenePhrase(phraseId: 'bed_2', english: 'Good night, sweetie.', chinese: '晚安，宝贝。', scene: PracticeScene.bedtime),
      const ScenePhrase(phraseId: 'bed_3', english: 'Close your eyes.', chinese: '闭上眼睛。', scene: PracticeScene.bedtime),
      const ScenePhrase(phraseId: 'bed_4', english: 'I love you.', chinese: '我爱你。', scene: PracticeScene.bedtime),
      const ScenePhrase(phraseId: 'bed_5', english: 'Sleep tight.', chinese: '睡个好觉。', scene: PracticeScene.bedtime),
    ],
    PracticeScene.outing: [
      const ScenePhrase(phraseId: 'out_1', english: 'Let\'s go outside!', chinese: '我们出去吧！', scene: PracticeScene.outing),
      const ScenePhrase(phraseId: 'out_2', english: 'Put on your shoes.', chinese: '穿上鞋子。', scene: PracticeScene.outing),
      const ScenePhrase(phraseId: 'out_3', english: 'The sun is shining.', chinese: '太阳在照耀。', scene: PracticeScene.outing),
    ],
  };

  List<ScenePhrase> getPhrases(PracticeScene scene) {
    return _phraseBank[scene] ?? [];
  }

  ScenePhrase? getRandomPhrase(
    PracticeScene scene,
    Set<String> usedPhraseIds,
  ) {
    final available = getPhrases(scene)
        .where((p) => !usedPhraseIds.contains(p.phraseId))
        .toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }
}
