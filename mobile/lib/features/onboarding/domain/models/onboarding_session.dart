import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingSession {
  OnboardingSession({
    String? childName,
    this.selectedScene,
    this.ageBucket,
    List<PracticeRecord>? records,
  }) : childName = childName ?? '',
       records = records ?? [];

  String? childName;
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
      records.isNotEmpty &&
      records.every((r) => r.reaction == BabyReaction.noResponse);

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
