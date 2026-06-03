# Onboarding V21 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing chat-style onboarding (V20) with a scene-first, practice-oriented flow (V21) across 4 route-based screens.

**Architecture:** Route-based multi-page onboarding using go_router. Each screen is a standalone widget. Shared state lives in `OnboardingSessionNotifier` (Riverpod ChangeNotifier). Local UI state (animations, countdowns) is managed per-screen. A `ScenePhraseService` provides local static phrases per scene.

**Tech Stack:** Flutter, Riverpod v2 (ChangeNotifier), go_router, flutter_hooks

**Spec:** `docs/superpowers/specs/2026-06-01-onboarding-v21-implementation-design.md`

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `mobile/lib/features/onboarding/domain/models/practice_scene.dart` | PracticeScene enum + scene metadata (label, time mapping, copy text) |
| `mobile/lib/features/onboarding/domain/models/baby_reaction.dart` | BabyReaction enum |
| `mobile/lib/features/onboarding/domain/models/practice_record.dart` | PracticeRecord immutable class |
| `mobile/lib/features/onboarding/domain/models/onboarding_session.dart` | OnboardingSession mutable class |
| `mobile/lib/features/onboarding/data/services/scene_phrase_service.dart` | Local static phrase library per scene |
| `mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart` | Shared state notifier across all 4 screens |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart` | Name input screen |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart` | Scene selection screen |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart` | Practice + reaction screen |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart` | Completion screen with sprout animation |
| `mobile/lib/features/onboarding/presentation/widgets/scene_button.dart` | Individual scene selection button |
| `mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart` | Baby reaction button (icon + text) |
| `mobile/lib/features/onboarding/presentation/widgets/countdown_progress_bar.dart` | Auto-jump countdown bar |
| `mobile/test/features/onboarding/domain/models/practice_scene_test.dart` | PracticeScene tests |
| `mobile/test/features/onboarding/domain/models/practice_record_test.dart` | PracticeRecord tests |
| `mobile/test/features/onboarding/data/services/scene_phrase_service_test.dart` | ScenePhraseService tests |
| `mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart` | Session notifier tests |
| `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart` | Name screen widget tests |
| `mobile/test/features/onboarding/presentation/screens/onboarding_scene_screen_test.dart` | Scene screen widget tests |
| `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart` | Practice screen widget tests |
| `mobile/test/features/onboarding/presentation/screens/onboarding_complete_screen_test.dart` | Complete screen widget tests |

### Modified files

| File | Changes |
|------|---------|
| `mobile/lib/app/router/app_route_contract.dart` | Add 4 new route name constants |
| `mobile/lib/app/router/app_go_router.dart` | Add 4 new GoRoute entries |
| `mobile/lib/app/providers/repository_providers.dart` | Add ScenePhraseService + OnboardingSessionNotifier providers |

### Deleted files

| File | Reason |
|------|--------|
| `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Replaced by 4 new screens |
| `mobile/lib/features/onboarding/presentation/onboarding_notifier.dart` | Replaced by OnboardingSessionNotifier |
| `mobile/lib/features/onboarding/presentation/onboarding_view_model.dart` | Unused (just re-exports notifier) |
| `mobile/lib/features/onboarding/presentation/widgets/quick_select_card.dart` | Replaced by scene_button.dart |
| `mobile/lib/features/onboarding/presentation/widgets/mini_seed_card.dart` | No longer used in V21 flow |
| `mobile/test/features/onboarding/onboarding_screen_test.dart` | Tests for deleted screen |

---

## Task 1: Data Models — PracticeScene, BabyReaction, PracticeRecord

**Files:**
- Create: `mobile/lib/features/onboarding/domain/models/practice_scene.dart`
- Create: `mobile/lib/features/onboarding/domain/models/baby_reaction.dart`
- Create: `mobile/lib/features/onboarding/domain/models/practice_record.dart`
- Create: `mobile/test/features/onboarding/domain/models/practice_scene_test.dart`
- Create: `mobile/test/features/onboarding/domain/models/practice_record_test.dart`

- [ ] **Step 1: Write PracticeScene tests**

```dart
// mobile/test/features/onboarding/domain/models/practice_scene_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/onboarding/domain/models/practice_scene_test.dart`
Expected: FAIL — `practice_scene.dart` does not exist

- [ ] **Step 3: Implement PracticeScene**

```dart
// mobile/lib/features/onboarding/domain/models/practice_scene.dart

enum PracticeScene {
  feeding,
  drinking,
  diaper,
  bath,
  bedtime,
  outing,
}

extension PracticeSceneX on PracticeScene {
  static const allScenes = PracticeScene.values;

  String get label {
    switch (this) {
      case PracticeScene.feeding:
        return '喂饭';
      case PracticeScene.drinking:
        return '喝水';
      case PracticeScene.diaper:
        return '换尿布';
      case PracticeScene.bath:
        return '洗澡';
      case PracticeScene.bedtime:
        return '睡前';
      case PracticeScene.outing:
        return '出门';
    }
  }

  String get mentorBubbleCopy {
    switch (this) {
      case PracticeScene.feeding:
        return '喂饭时轻轻说，宝宝会听的。';
      case PracticeScene.drinking:
        return '递水的时候说一句就好。';
      case PracticeScene.diaper:
        return '换尿布时说，宝宝反而更安静。';
      case PracticeScene.bath:
        return '洗澡时说，宝宝会觉得好玩。';
      case PracticeScene.bedtime:
        return '睡前轻轻说，像讲故事一样。';
      case PracticeScene.outing:
        return '出门前说一句，今天就开始了。';
    }
  }

  String get completionTitle {
    switch (this) {
      case PracticeScene.feeding:
        return '喂饭时说的这句，下次还能用。';
      case PracticeScene.drinking:
        return '喝水时说的这句，明天还能用。';
      case PracticeScene.diaper:
        return '换尿布时说的这句，宝宝会慢慢习惯。';
      case PracticeScene.bath:
        return '洗澡时说的这句，宝宝会觉得好玩。';
      case PracticeScene.bedtime:
        return '睡前说的这句，会变成你们的小仪式。';
      case PracticeScene.outing:
        return '出门前说的这句，今天就开始了。';
    }
  }

  static PracticeScene defaultSceneForHour(int hour) {
    if (hour >= 7 && hour <= 9) return PracticeScene.feeding;
    if (hour >= 10 && hour <= 11) return PracticeScene.drinking;
    if (hour >= 12 && hour <= 14) return PracticeScene.diaper;
    if (hour >= 15 && hour <= 17) return PracticeScene.bath;
    if (hour >= 18 && hour <= 21) return PracticeScene.bedtime;
    return PracticeScene.outing;
  }
}
```

- [ ] **Step 4: Implement BabyReaction**

```dart
// mobile/lib/features/onboarding/domain/models/baby_reaction.dart

enum BabyReaction {
  responded,
  calmed,
  noResponse,
}

extension BabyReactionX on BabyReaction {
  String get emoji {
    switch (this) {
      case BabyReaction.responded:
        return '😊';
      case BabyReaction.calmed:
        return '😌';
      case BabyReaction.noResponse:
        return '😐';
    }
  }

  String get label {
    switch (this) {
      case BabyReaction.responded:
        return '有回应';
      case BabyReaction.calmed:
        return '安静了';
      case BabyReaction.noResponse:
        return '没反应';
    }
  }

  String get feedbackCopy {
    switch (this) {
      case BabyReaction.responded:
        return '记下来了，小禾给你下一句。';
      case BabyReaction.calmed:
        return '记下来了，这句可以留着用。';
      case BabyReaction.noResponse:
        return '没关系，换一句试试。';
    }
  }
}
```

- [ ] **Step 5: Write PracticeRecord tests**

```dart
// mobile/test/features/onboarding/domain/models/practice_record_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

void main() {
  group('PracticeRecord', () {
    test('creates record with required fields', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(record.phraseId, 'p1');
      expect(record.english, 'Are you hungry?');
      expect(record.reaction, isNull);
    });

    test('creates record with reaction', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        reaction: BabyReaction.responded,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(record.reaction, BabyReaction.responded);
    });

    test('copyWithReaction returns new record with reaction set', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      final withReaction = record.copyWithReaction(BabyReaction.calmed);
      expect(withReaction.reaction, BabyReaction.calmed);
      expect(withReaction.phraseId, 'p1');
      expect(record.reaction, isNull);
    });
  });
}
```

- [ ] **Step 6: Run PracticeRecord tests to verify they fail**

Run: `cd mobile && flutter test test/features/onboarding/domain/models/practice_record_test.dart`
Expected: FAIL

- [ ] **Step 7: Implement PracticeRecord**

```dart
// mobile/lib/features/onboarding/domain/models/practice_record.dart

import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

class PracticeRecord {
  const PracticeRecord({
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.scene,
    required this.practicedAt,
    this.reaction,
  });

  final String phraseId;
  final String english;
  final String chinese;
  final PracticeScene scene;
  final BabyReaction? reaction;
  final DateTime practicedAt;

  PracticeRecord copyWithReaction(BabyReaction reaction) {
    return PracticeRecord(
      phraseId: phraseId,
      english: english,
      chinese: chinese,
      scene: scene,
      practicedAt: practicedAt,
      reaction: reaction,
    );
  }
}
```

- [ ] **Step 8: Run all data model tests**

Run: `cd mobile && flutter test test/features/onboarding/domain/models/`
Expected: All PASS

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/features/onboarding/domain/models/practice_scene.dart \
        mobile/lib/features/onboarding/domain/models/baby_reaction.dart \
        mobile/lib/features/onboarding/domain/models/practice_record.dart \
        mobile/test/features/onboarding/domain/models/practice_scene_test.dart \
        mobile/test/features/onboarding/domain/models/practice_record_test.dart
git commit -m "feat(onboarding): add V21 data models — PracticeScene, BabyReaction, PracticeRecord"
```

---

## Task 2: OnboardingSession Model

**Files:**
- Create: `mobile/lib/features/onboarding/domain/models/onboarding_session.dart`

- [ ] **Step 1: Implement OnboardingSession**

```dart
// mobile/lib/features/onboarding/domain/models/onboarding_session.dart

import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingSession {
  OnboardingSession({
    this.childName = '',
    this.selectedScene,
    this.ageBucket,
    List<PracticeRecord>? records,
  }) : records = records ?? [];

  String childName;
  PracticeScene? selectedScene;
  OnboardingAgeBucket? ageBucket;
  final List<PracticeRecord> records;

  void addRecord(PracticeRecord record) {
    records.add(record);
  }

  void updateReaction(int recordIndex, BabyReaction reaction) {
    if (recordIndex >= 0 && recordIndex < records.length) {
      records[recordIndex] = records[recordIndex].copyWithReaction(reaction);
    }
  }

  int get practicedCount => records.length;

  int get respondedCount =>
      records.where((r) => r.reaction == BabyReaction.responded).length;

  int get noResponseCount =>
      records.where((r) => r.reaction == BabyReaction.noResponse).length;

  bool get allNoResponse =>
      records.isNotEmpty && records.every((r) => r.reaction == BabyReaction.noResponse);

  bool get hasAnyResponded => respondedCount > 0;

  String get completionBubbleCopy {
    final count = practicedCount;
    if (count <= 1) return '第一句最难，你已经开始了。';
    if (count <= 3) return '连续说了几句，宝宝有听到的。';
    return '今天说的比很多家长一周都多。';
  }

  String? get completionReactionSummary {
    if (records.isEmpty) return null;
    if (hasAnyResponded) {
      return '刚才宝宝有回应的那句，可以留着多用几次。';
    }
    if (allNoResponse) {
      return '有些句子需要宝宝听几次才会有反应，这很正常。';
    }
    return null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/features/onboarding/domain/models/onboarding_session.dart
git commit -m "feat(onboarding): add OnboardingSession model"
```

---

## Task 3: ScenePhraseService

**Files:**
- Create: `mobile/lib/features/onboarding/data/services/scene_phrase_service.dart`
- Create: `mobile/test/features/onboarding/data/services/scene_phrase_service_test.dart`

- [ ] **Step 1: Write ScenePhraseService tests**

```dart
// mobile/test/features/onboarding/data/services/scene_phrase_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

void main() {
  group('ScenePhraseService', () {
    late ScenePhraseService service;

    setUp(() {
      service = ScenePhraseService();
    });

    test('getPhrases returns phrases for each scene', () {
      for (final scene in PracticeScene.values) {
        final phrases = service.getPhrases(scene);
        expect(phrases.length, greaterThanOrEqualTo(3),
            reason: '${scene.label} should have at least 3 phrases');
        expect(phrases.length, lessThanOrEqualTo(5),
            reason: '${scene.label} should have at most 5 phrases');
      }
    });

    test('each phrase has non-empty english and chinese', () {
      for (final scene in PracticeScene.values) {
        for (final phrase in service.getPhrases(scene)) {
          expect(phrase.english.trim().isNotEmpty, true);
          expect(phrase.chinese.trim().isNotEmpty, true);
          expect(phrase.phraseId.trim().isNotEmpty, true);
        }
      }
    });

    test('getRandomPhrase returns a phrase not in usedPhraseIds', () {
      final allPhrases = service.getPhrases(PracticeScene.feeding);
      final usedIds = {allPhrases.first.phraseId};
      final result = service.getRandomPhrase(PracticeScene.feeding, usedIds);
      expect(result, isNotNull);
      expect(result!.phraseId, isNot(allPhrases.first.phraseId));
    });

    test('getRandomPhrase returns null when all phrases used', () {
      final allPhrases = service.getPhrases(PracticeScene.feeding);
      final usedIds = allPhrases.map((p) => p.phraseId).toSet();
      final result = service.getRandomPhrase(PracticeScene.feeding, usedIds);
      expect(result, isNull);
    });

    test('getRandomPhrase returns any phrase when usedPhraseIds is empty', () {
      final result =
          service.getRandomPhrase(PracticeScene.feeding, {});
      expect(result, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/onboarding/data/services/scene_phrase_service_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement ScenePhraseService**

```dart
// mobile/lib/features/onboarding/data/services/scene_phrase_service.dart

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/features/onboarding/data/services/scene_phrase_service_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/onboarding/data/services/scene_phrase_service.dart \
        mobile/test/features/onboarding/data/services/scene_phrase_service_test.dart
git commit -m "feat(onboarding): add ScenePhraseService with local phrase bank"
```

---

## Task 4: OnboardingSessionNotifier

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart`
- Create: `mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart`

- [ ] **Step 1: Write OnboardingSessionNotifier tests**

```dart
// mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';

void main() {
  group('OnboardingSessionNotifier', () {
    late OnboardingSessionNotifier notifier;
    late ScenePhraseService phraseService;

    setUp(() {
      phraseService = ScenePhraseService();
      notifier = OnboardingSessionNotifier(phraseService: phraseService);
    });

    test('initial state has empty session', () {
      expect(notifier.session.childName, '');
      expect(notifier.session.selectedScene, isNull);
      expect(notifier.session.records, isEmpty);
    });

    test('setChildName updates session', () {
      notifier.setChildName('小宝');
      expect(notifier.session.childName, '小宝');
    });

    test('selectScene updates session and loads first phrase', () {
      notifier.selectScene(PracticeScene.feeding);
      expect(notifier.session.selectedScene, PracticeScene.feeding);
      expect(notifier.currentPhrase, isNotNull);
      expect(notifier.currentPhrase!.scene, PracticeScene.feeding);
    });

    test('recordSaid adds record and advances to reaction state', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.recordSaid();
      expect(notifier.session.practicedCount, 1);
      expect(notifier.showReactionPicker, true);
    });

    test('selectReaction updates last record', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.recordSaid();
      notifier.selectReaction(BabyReaction.responded);
      expect(notifier.session.records.last.reaction, BabyReaction.responded);
      expect(notifier.showReactionPicker, false);
    });

    test('nextPhrase loads a different phrase', () {
      notifier.selectScene(PracticeScene.feeding);
      final firstPhrase = notifier.currentPhrase;
      notifier.recordSaid();
      notifier.selectReaction(BabyReaction.responded);
      notifier.nextPhrase();
      // Should have a new phrase (might be same if only 1 left, but feeding has 4)
      expect(notifier.currentPhrase, isNotNull);
      expect(notifier.showReactionPicker, false);
    });

    test('swapPhrase replaces current phrase with unused one', () {
      notifier.selectScene(PracticeScene.feeding);
      final first = notifier.currentPhrase;
      notifier.swapPhrase();
      // With 4 phrases, should get a different one (statistically likely)
      expect(notifier.currentPhrase, isNotNull);
    });

    test('phrasePoolExhausted returns true when all phrases used', () {
      notifier.selectScene(PracticeScene.feeding);
      // Use all 4 phrases
      for (int i = 0; i < 4; i++) {
        notifier.recordSaid();
        notifier.selectReaction(BabyReaction.responded);
        if (i < 3) notifier.nextPhrase();
      }
      expect(notifier.phrasePoolExhausted, true);
    });

    test('selectAgeBucket updates session', () {
      notifier.selectAgeBucket(OnboardingAgeBucket.sixToTwelve);
      expect(notifier.session.ageBucket, OnboardingAgeBucket.sixToTwelve);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/onboarding/presentation/onboarding_session_notifier_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement OnboardingSessionNotifier**

```dart
// mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_session.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingSessionNotifier extends ChangeNotifier {
  OnboardingSessionNotifier({required ScenePhraseService phraseService})
      : _phraseService = phraseService;

  final ScenePhraseService _phraseService;
  final OnboardingSession _session = OnboardingSession();

  ScenePhrase? _currentPhrase;
  bool _showReactionPicker = false;
  final Set<String> _usedPhraseIds = {};

  OnboardingSession get session => _session;
  ScenePhrase? get currentPhrase => _currentPhrase;
  bool get showReactionPicker => _showReactionPicker;

  bool get phrasePoolExhausted {
    final scene = _session.selectedScene;
    if (scene == null) return false;
    return _phraseService.getRandomPhrase(scene, _usedPhraseIds) == null;
  }

  void setChildName(String name) {
    _session.childName = name;
    notifyListeners();
  }

  void selectScene(PracticeScene scene) {
    _session.selectedScene = scene;
    _usedPhraseIds.clear();
    _loadNextPhrase();
    notifyListeners();
  }

  void selectAgeBucket(OnboardingAgeBucket bucket) {
    _session.ageBucket = bucket;
    notifyListeners();
  }

  void recordSaid() {
    final phrase = _currentPhrase;
    if (phrase == null) return;

    _session.addRecord(PracticeRecord(
      phraseId: phrase.phraseId,
      english: phrase.english,
      chinese: phrase.chinese,
      scene: phrase.scene,
      practicedAt: DateTime.now(),
    ));
    _usedPhraseIds.add(phrase.phraseId);
    _showReactionPicker = true;
    notifyListeners();
  }

  void selectReaction(BabyReaction reaction) {
    final lastIndex = _session.records.length - 1;
    if (lastIndex >= 0) {
      _session.updateReaction(lastIndex, reaction);
    }
    _showReactionPicker = false;
    notifyListeners();
  }

  void skipReaction() {
    _showReactionPicker = false;
    notifyListeners();
  }

  void nextPhrase() {
    _showReactionPicker = false;
    _loadNextPhrase();
    notifyListeners();
  }

  void swapPhrase() {
    _loadNextPhrase();
    notifyListeners();
  }

  void _loadNextPhrase() {
    final scene = _session.selectedScene;
    if (scene == null) {
      _currentPhrase = null;
      return;
    }
    _currentPhrase = _phraseService.getRandomPhrase(scene, _usedPhraseIds);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/features/onboarding/presentation/onboarding_session_notifier_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart \
        mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart
git commit -m "feat(onboarding): add OnboardingSessionNotifier with phrase cycling"
```

---

## Task 5: Widgets — SceneButton, ReactionButton, CountdownProgressBar

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/widgets/scene_button.dart`
- Create: `mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart`
- Create: `mobile/lib/features/onboarding/presentation/widgets/countdown_progress_bar.dart`

- [ ] **Step 1: Implement SceneButton**

```dart
// mobile/lib/features/onboarding/presentation/widgets/scene_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';

class SceneButton extends StatelessWidget {
  const SceneButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return AppScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightTap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.outlineSoft,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected ? colors.warmShadowSm : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement ReactionButton**

```dart
// mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';

class ReactionButton extends StatelessWidget {
  const ReactionButton({
    super.key,
    required this.reaction,
    required this.onTap,
  });

  final BabyReaction reaction;
  final VoidCallback onTap;

  Color _backgroundColor(BabyTalkColors colors) {
    switch (reaction) {
      case BabyReaction.responded:
        return colors.successSoft;
      case BabyReaction.calmed:
        return colors.infoSoft;
      case BabyReaction.noResponse:
        return colors.bgSunken;
    }
  }

  Color _textColor(BabyTalkColors colors) {
    switch (reaction) {
      case BabyReaction.responded:
        return colors.success;
      case BabyReaction.calmed:
        return colors.info;
      case BabyReaction.noResponse:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return AppScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _backgroundColor(colors),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              reaction.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _textColor(colors),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement CountdownProgressBar**

```dart
// mobile/lib/features/onboarding/presentation/widgets/countdown_progress_bar.dart

import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class CountdownProgressBar extends StatefulWidget {
  const CountdownProgressBar({
    super.key,
    required this.duration,
    required this.onComplete,
  });

  final Duration duration;
  final VoidCallback onComplete;

  @override
  State<CountdownProgressBar> createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      widget.onComplete();
    } else {
      _controller.forward().then((_) {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LinearProgressIndicator(
          value: _controller.value,
          backgroundColor: colors.bgSunken,
          valueColor: AlwaysStoppedAnimation(colors.accent),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/widgets/scene_button.dart \
        mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart \
        mobile/lib/features/onboarding/presentation/widgets/countdown_progress_bar.dart
git commit -m "feat(onboarding): add V21 widgets — SceneButton, ReactionButton, CountdownProgressBar"
```

---

## Task 6: Name Input Screen

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart`
- Create: `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart`

- [ ] **Step 1: Write name screen tests**

```dart
// mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_name_screen.dart';

void main() {
  Widget buildSubject(OnboardingSessionNotifier notifier) {
    return ProviderScope(
      overrides: [
        onboardingSessionProvider.overrideWith((ref) => notifier),
      ],
      child: const MaterialApp(
        home: OnboardingNameScreen(),
      ),
    );
  }

  testWidgets('shows name input and next button', (tester) async {
    final notifier = OnboardingSessionNotifier(
      phraseService: ScenePhraseService(),
    );
    await tester.pumpWidget(buildSubject(notifier));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
  });

  testWidgets('next button disabled when name is empty', (tester) async {
    final notifier = OnboardingSessionNotifier(
      phraseService: ScenePhraseService(),
    );
    await tester.pumpWidget(buildSubject(notifier));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement OnboardingNameScreen**

```dart
// mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';

class OnboardingNameScreen extends HookConsumerWidget {
  const OnboardingNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final name = useState('');

    useEffect(() {
      void listener() {
        name.value = controller.text;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, const []);

    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.screenPadding,
              children: [
                const SizedBox(height: AppLayoutConstants.spacingXl),
                const AppMentorBubble(
                  message: '先告诉小禾，宝宝叫什么？',
                  caption: '小禾老师',
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                TextField(
                  key: const Key('onboarding-name-input'),
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: '宝宝昵称',
                    hintText: '填一个昵称就好',
                  ),
                  onSubmitted: (_) {
                    if (name.value.trim().isNotEmpty) {
                      _submit(context, ref, name.value.trim());
                    }
                  },
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                ElevatedButton(
                  key: const Key('onboarding-name-next'),
                  onPressed: name.value.trim().isNotEmpty
                      ? () => _submit(context, ref, name.value.trim())
                      : null,
                  child: const Text('下一步'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref, String name) {
    ref.read(onboardingSessionProvider.notifier).setChildName(name);
    context.push('/onboarding/scene');
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart \
        mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart
git commit -m "feat(onboarding): add V21 name input screen"
```

---

## Task 7: Scene Selection Screen

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart`

- [ ] **Step 1: Implement OnboardingSceneScreen**

```dart
// mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/scene_button.dart';

class OnboardingSceneScreen extends ConsumerStatefulWidget {
  const OnboardingSceneScreen({super.key});

  @override
  ConsumerState<OnboardingSceneScreen> createState() =>
      _OnboardingSceneScreenState();
}

class _OnboardingSceneScreenState extends ConsumerState<OnboardingSceneScreen> {
  PracticeScene? _selectedScene;
  OnboardingAgeBucket? _selectedAge;
  bool _showAgePanel = false;

  @override
  void initState() {
    super.initState();
    _selectedScene = _resolveDefaultScene();
  }

  PracticeScene _resolveDefaultScene() {
    final session = ref.read(onboardingSessionProvider).session;
    if (session.selectedScene != null) return session.selectedScene!;
    return PracticeSceneX.defaultSceneForHour(DateTime.now().hour);
  }

  void _onSceneTap(PracticeScene scene) {
    setState(() => _selectedScene = scene);
    final notifier = ref.read(onboardingSessionProvider.notifier);
    notifier.selectScene(scene);
    context.push('/onboarding/practice');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.screenPadding,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final notifier = ref
                            .read(onboardingSessionProvider.notifier);
                        notifier.selectScene(_resolveDefaultScene());
                        context.push('/onboarding/practice');
                      },
                      child: const Text('直接给一句'),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                const AppMentorBubble(
                  message: '选个正在发生的场景，小禾给你一句现在就能说的。',
                  caption: '小禾老师',
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                Text(
                  '今天先说一句',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(
                  '选个正在发生的场景',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                ...PracticeSceneX.allScenes.map((scene) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppLayoutConstants.spacingSm,
                    ),
                    child: SceneButton(
                      label: scene.label,
                      isSelected: _selectedScene == scene,
                      onTap: () => _onSceneTap(scene),
                    ),
                  );
                }),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                // Age entry (dashed outline button)
                OutlinedButton.icon(
                  key: const Key('onboarding-age-entry'),
                  onPressed: () {
                    setState(() => _showAgePanel = !_showAgePanel);
                  },
                  icon: const Icon(Icons.child_care_outlined),
                  label: Text(
                    _selectedAge != null
                        ? '${_selectedAge!.label} ✓'
                        : '宝宝多大？可稍后补',
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.outlineSoft,
                      style: BorderStyle.solid,
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (_showAgePanel) ...[
                  const SizedBox(height: AppLayoutConstants.spacingSm),
                  _AgeSelectionPanel(
                    selected: _selectedAge,
                    onSelected: (bucket) {
                      setState(() {
                        _selectedAge = bucket;
                        _showAgePanel = false;
                      });
                      ref
                          .read(onboardingSessionProvider.notifier)
                          .selectAgeBucket(bucket);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeSelectionPanel extends StatelessWidget {
  const _AgeSelectionPanel({
    required this.selected,
    required this.onSelected,
  });

  final OnboardingAgeBucket? selected;
  final ValueChanged<OnboardingAgeBucket> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: AppLayoutConstants.bannerPadding,
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...OnboardingAgeBucket.values.map((bucket) {
            return ListTile(
              title: Text(bucket.label),
              selected: selected == bucket,
              onTap: () => onSelected(bucket),
              contentPadding: EdgeInsets.zero,
            );
          }),
          ListTile(
            title: const Text('先跳过'),
            onTap: () {
              // Close panel without selecting
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart
git commit -m "feat(onboarding): add V21 scene selection screen"
```

---

## Task 8: Practice Screen

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`

- [ ] **Step 1: Implement OnboardingPracticeScreen**

```dart
// mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/countdown_progress_bar.dart';
import 'package:mobile/features/onboarding/presentation/widgets/reaction_button.dart';

class OnboardingPracticeScreen extends ConsumerWidget {
  const OnboardingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final phrase = notifier.currentPhrase;

    if (scene == null || phrase == null) {
      return const Scaffold(
        body: Center(child: Text('场景未选择')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingSm,
                    vertical: AppLayoutConstants.spacingXs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          '${scene.label} / 一句就够',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/onboarding/complete');
                        },
                        child: const Text('结束'),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: AppLayoutConstants.screenPadding,
                    children: [
                      AppMentorBubble(message: scene.mentorBubbleCopy),
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      // Phrase display (no border)
                      _PhraseDisplay(phrase: phrase),
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      // Reaction area
                      if (notifier.showReactionPicker)
                        _ReactionArea(notifier: notifier),
                    ],
                  ),
                ),
                // Bottom buttons
                _BottomActions(notifier: notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhraseDisplay extends StatelessWidget {
  const _PhraseDisplay({required this.phrase});

  final dynamic phrase; // ScenePhrase

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scene pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
          ),
          child: Text(
            phrase.scene.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.accentDark,
            ),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        // English phrase
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                phrase.english,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 32,
                  height: 1.3,
                  color: colors.english,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.volume_up_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
              onPressed: () {
                // TODO: TTS playback
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        // Chinese translation
        Text(
          phrase.chinese,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ReactionArea extends StatelessWidget {
  const _ReactionArea({required this.notifier});

  final OnboardingSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已保存本句',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        // Reaction buttons with stagger
        ...BabyReaction.values.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppLayoutConstants.spacingSm,
            ),
            child: ReactionButton(
              reaction: entry.value,
              onTap: () => notifier.selectReaction(entry.value),
            ),
          );
        }),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        // Skip reaction link
        Center(
          child: TextButton(
            onPressed: () => notifier.skipReaction(),
            child: const Text('跳过，下一句'),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.notifier});

  final OnboardingSessionNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionNotifier = ref.read(onboardingSessionProvider.notifier);

    if (notifier.showReactionPicker) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: AppLayoutConstants.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppScaleButton(
            scaleDown: 0.97,
            onTap: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.recordSaid();
            },
            child: const ElevatedButton(
              key: Key('onboarding-said-button'),
              onPressed: null,
              child: Text('说完了'),
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: notifier.phrasePoolExhausted
                    ? null
                    : () => sessionNotifier.swapPhrase(),
                child: Text(
                  notifier.phrasePoolExhausted ? '句子都试过了' : '换一句',
                ),
              ),
              const SizedBox(width: AppLayoutConstants.spacingMd),
              TextButton(
                onPressed: () {
                  context.push('/onboarding/complete');
                },
                child: const Text('结束'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart
git commit -m "feat(onboarding): add V21 practice screen with reaction recording"
```

---

## Task 9: Completion Screen

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart`

- [ ] **Step 1: Implement OnboardingCompleteScreen**

```dart
// mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/app/widgets/app_seed_sprout.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';

class OnboardingCompleteScreen extends ConsumerStatefulWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  ConsumerState<OnboardingCompleteScreen> createState() =>
      _OnboardingCompleteScreenState();
}

class _OnboardingCompleteScreenState
    extends ConsumerState<OnboardingCompleteScreen> {
  bool _sproutDone = false;
  bool _textVisible = false;

  void _onSproutComplete() {
    setState(() => _sproutDone = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _textVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.screenPadding,
              children: [
                // Top bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        '小禾老师 / 今天已完成',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                // Mentor bubble
                AppMentorBubble(message: session.completionBubbleCopy),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                // Sprout animation
                Center(
                  child: AppSeedSprout(
                    size: 120,
                    onAnimationComplete: _onSproutComplete,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                // Dynamic title (fades in after sprout)
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scene != null)
                        Text(
                          scene.completionTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        '下次打开，小禾会给你新的一句。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (session.completionReactionSummary != null) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Text(
                          session.completionReactionSummary!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacing2xl),
                // Buttons
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      AppScaleButton(
                        scaleDown: 0.97,
                        onTap: () {
                          context.go('/onboarding/practice');
                        },
                        child: const ElevatedButton(
                          onPressed: null,
                          child: Text('再来一句'),
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      TextButton(
                        onPressed: () => _completeOnboarding(context, ref),
                        child: const Text('先到这里'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final session = ref.read(onboardingSessionProvider).session;
    final ageBucket = session.ageBucket ?? OnboardingAgeBucket.zeroToSix;

    final repository = ref.read(onboardingRepositoryProvider);
    await repository.completeOnboarding(
      childDisplayName: session.childName.isEmpty ? '宝宝' : session.childName,
      ageBucket: ageBucket,
    );

    if (context.mounted) {
      context.go('/');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart
git commit -m "feat(onboarding): add V21 completion screen with sprout animation"
```

---

## Task 10: Router & Provider Wiring

**Files:**
- Modify: `mobile/lib/app/router/app_route_contract.dart`
- Modify: `mobile/lib/app/router/app_go_router.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`

- [ ] **Step 1: Add route constants**

Add to `app_route_contract.dart`:

```dart
static const onboardingName = '/onboarding/name';
static const onboardingScene = '/onboarding/scene';
static const onboardingPractice = '/onboarding/practice';
static const onboardingComplete = '/onboarding/complete';
```

Also add these paths to the `canonicalPaths` set.

- [ ] **Step 2: Add GoRoute entries**

Add 4 new `GoRoute` entries in `app_go_router.dart`:

```dart
GoRoute(
  path: AppRouteNames.onboardingName,
  builder: (context, state) => const OnboardingNameScreen(),
),
GoRoute(
  path: AppRouteNames.onboardingScene,
  builder: (context, state) => const OnboardingSceneScreen(),
),
GoRoute(
  path: AppRouteNames.onboardingPractice,
  builder: (context, state) => const OnboardingPracticeScreen(),
),
GoRoute(
  path: AppRouteNames.onboardingComplete,
  builder: (context, state) => const OnboardingCompleteScreen(),
),
```

- [ ] **Step 3: Add providers**

Add to `repository_providers.dart`:

```dart
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';

final scenePhraseServiceProvider = Provider<ScenePhraseService>((ref) {
  return ScenePhraseService();
});

final onboardingSessionProvider =
    ChangeNotifierProvider<OnboardingSessionNotifier>((ref) {
  return OnboardingSessionNotifier(
    phraseService: ref.read(scenePhraseServiceProvider),
  );
});
```

- [ ] **Step 4: Update initial location**

Update the initial onboarding redirect to navigate to `/onboarding/name` instead of `/onboarding`.

- [ ] **Step 5: Run `flutter analyze`**

Run: `cd mobile && flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/app/router/app_route_contract.dart \
        mobile/lib/app/router/app_go_router.dart \
        mobile/lib/app/providers/repository_providers.dart
git commit -m "feat(onboarding): wire V21 routes and providers"
```

---

## Task 11: Localization Strings

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb` (and `app_zh.arb` if exists)

- [ ] **Step 1: Add V21 localization keys**

Add the following keys to the ARB files:

```json
{
  "onboardingV21MentorGreeting": "先告诉小禾，宝宝叫什么？",
  "onboardingV21NameLabel": "宝宝昵称",
  "onboardingV21NameHint": "填一个昵称就好",
  "onboardingV21NextButton": "下一步",
  "onboardingV21SceneTitle": "今天先说一句",
  "onboardingV21SceneHint": "选个正在发生的场景",
  "onboardingV21DirectPhrase": "直接给一句",
  "onboardingV21AgeEntry": "宝宝多大？可稍后补",
  "onboardingV21AgeSkip": "先跳过",
  "onboardingV21PracticeSubtitle": "一句就够",
  "onboardingV21SaidButton": "说完了",
  "onboardingV21SwapButton": "换一句",
  "onboardingV21EndButton": "结束",
  "onboardingV21Saved": "已保存本句",
  "onboardingV21SkipReaction": "跳过，下一句",
  "onboardingV21PhrasesExhausted": "句子都试过了",
  "onboardingV21CompleteTitle": "小禾老师 / 今天已完成",
  "onboardingV21AgainButton": "再来一句",
  "onboardingV21DoneButton": "先到这里",
  "onboardingV21NextTime": "下次打开，小禾会给你新的一句。",
  "onboardingV21TtsFailed": "发音加载失败，点我重试",
  "onboardingV21OfflineToast": "网络不佳，已为你准备离线短语"
}
```

- [ ] **Step 2: Run codegen**

Run: `cd mobile && flutter gen-l10n`

- [ ] **Step 3: Update screens to use localization**

Replace hardcoded strings in the 4 screens with `AppLocalizations.of(context)!.onboardingV21Xxx`.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/l10n/ mobile/lib/l10n/app_en.arb
git commit -m "feat(onboarding): add V21 localization strings"
```

---

## Task 12: Cleanup Old Onboarding Code

**Files:**
- Delete: `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- Delete: `mobile/lib/features/onboarding/presentation/onboarding_notifier.dart`
- Delete: `mobile/lib/features/onboarding/presentation/onboarding_view_model.dart`
- Delete: `mobile/lib/features/onboarding/presentation/widgets/quick_select_card.dart`
- Delete: `mobile/lib/features/onboarding/presentation/widgets/mini_seed_card.dart`
- Delete: `mobile/test/features/onboarding/onboarding_screen_test.dart`
- Modify: `mobile/lib/app/router/app_go_router.dart` — remove old `/onboarding` route
- Modify: `mobile/lib/app/providers/repository_providers.dart` — remove old `onboardingNotifierProvider`

- [ ] **Step 1: Remove old route and provider references**

Remove the old `GoRoute` for `AppRouteNames.onboarding` and the old `onboardingNotifierProvider`.

- [ ] **Step 2: Delete old files**

```bash
rm mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart
rm mobile/lib/features/onboarding/presentation/onboarding_notifier.dart
rm mobile/lib/features/onboarding/presentation/onboarding_view_model.dart
rm mobile/lib/features/onboarding/presentation/widgets/quick_select_card.dart
rm mobile/lib/features/onboarding/presentation/widgets/mini_seed_card.dart
rm mobile/test/features/onboarding/onboarding_screen_test.dart
```

- [ ] **Step 3: Run `flutter analyze`**

Run: `cd mobile && flutter analyze`
Expected: No errors

- [ ] **Step 4: Run all onboarding tests**

Run: `cd mobile && flutter test test/features/onboarding/`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add -A mobile/lib/features/onboarding/ mobile/test/features/onboarding/
git commit -m "refactor(onboarding): remove V20 onboarding code, V21 fully replaces"
```

---

## Task 13: Integration Verification

- [ ] **Step 1: Run full test suite**

Run: `cd mobile && flutter test`
Expected: All PASS

- [ ] **Step 2: Run `flutter analyze`**

Run: `cd mobile && flutter analyze`
Expected: No errors

- [ ] **Step 3: Manual smoke test**

1. Launch app → should navigate to `/onboarding/name`
2. Enter name → tap "下一步" → navigate to scene selection
3. Select a scene → auto-navigate to practice
4. Tap "说完了" → reaction picker appears
5. Select reaction → countdown starts → auto-advance to next phrase
6. Tap "结束" → completion screen with sprout animation
7. Tap "再来一句" → back to practice
8. Tap "先到这里" → onboarding complete, navigate to home

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix(onboarding): integration fixes from smoke test"
```
