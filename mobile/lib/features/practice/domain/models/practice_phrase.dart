class PracticePhrase {
  const PracticePhrase({
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.step,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.difficulty,
    required this.audioAsset,
  });

  final String spaceId;
  final String activityId;
  final String phraseId;
  final int step;
  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
  final String audioAsset;

  String get audioPlayerAsset =>
      audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset;
}
