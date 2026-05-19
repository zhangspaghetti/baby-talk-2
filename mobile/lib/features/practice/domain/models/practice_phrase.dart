import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../../generated/features/practice/domain/models/practice_phrase.freezed.dart';

@freezed
class PracticePhrase with _$PracticePhrase {
  const PracticePhrase._();

  const factory PracticePhrase({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required int step,
    required String english,
    required String chinese,
    required String pronunciation,
    required String difficulty,
    required String audioAsset,
  }) = _PracticePhrase;

  String get audioPlayerAsset =>
      audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset;
}
