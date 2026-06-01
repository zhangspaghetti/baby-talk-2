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
