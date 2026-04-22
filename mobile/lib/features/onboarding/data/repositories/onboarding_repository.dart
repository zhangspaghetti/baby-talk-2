import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

class OnboardingStarterSeed {
  const OnboardingStarterSeed({
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.phraseEnglish,
    required this.phraseChinese,
  });

  final String spaceId;
  final String activityId;
  final String phraseId;
  final String phraseEnglish;
  final String phraseChinese;
}

class OnboardingRepository {
  OnboardingRepository({
    required OnboardingSnapshotStore snapshotStore,
    required PracticeRepository practiceRepository,
    required this.starterSpaceId,
    required this.starterActivityId,
  }) : _snapshotStore = snapshotStore,
       _practiceRepository = practiceRepository;

  final OnboardingSnapshotStore _snapshotStore;
  final PracticeRepository _practiceRepository;
  final String starterSpaceId;
  final String starterActivityId;

  Future<OnboardingSnapshot?> readSnapshot() async {
    try {
      return await _snapshotStore.read();
    } on FormatException {
      await _snapshotStore.deleteIfExists();
      return null;
    }
  }

  Future<OnboardingSnapshot?> readCompletedSnapshot() async {
    final snapshot = await readSnapshot();
    if (snapshot == null || !snapshot.isCompleted) {
      return null;
    }
    return snapshot;
  }

  Future<OnboardingStarterSeed> resolveStarterSeed() async {
    final activitySnapshot = await _practiceRepository.getActivitySnapshot(
      spaceId: starterSpaceId,
      activityId: starterActivityId,
    );
    if (activitySnapshot.phrases.isEmpty) {
      throw const FormatException('starter 内容不可用：活动缺少可用短语。');
    }

    final starterPhrase = activitySnapshot.phrases.first;
    if (starterPhrase.phraseId.trim().isEmpty ||
        starterPhrase.english.trim().isEmpty) {
      throw const FormatException('starter 内容不可用：首句短语缺失关键字段。');
    }

    return OnboardingStarterSeed(
      spaceId: activitySnapshot.spaceId,
      activityId: activitySnapshot.activityId,
      phraseId: starterPhrase.phraseId,
      phraseEnglish: starterPhrase.english,
      phraseChinese: starterPhrase.chinese,
    );
  }

  Future<OnboardingSnapshot> saveSnapshot(OnboardingSnapshot snapshot) async {
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<OnboardingSnapshot> completeOnboarding({
    required String childDisplayName,
    required OnboardingAgeBucket ageBucket,
    OnboardingConsentState consentState = OnboardingConsentState.localOnly,
    DateTime? birthDate,
    DateTime? completedAt,
  }) async {
    final trimmedDisplayName = childDisplayName.trim();
    if (trimmedDisplayName.isEmpty) {
      throw const FormatException('宝宝昵称不能为空。');
    }

    final stageMatch = StageMatchCatalog.forAgeBucket(ageBucket);
    final starterSeed = await resolveStarterSeed();
    final snapshot = OnboardingSnapshot(
      childDisplayName: trimmedDisplayName,
      ageBucket: ageBucket,
      approxMonths: stageMatch.approxMonths,
      currentStage: stageMatch.stageId,
      starterSpaceId: starterSeed.spaceId,
      starterActivityId: starterSeed.activityId,
      starterPhraseId: starterSeed.phraseId,
      completedAt: (completedAt ?? DateTime.now()).toUtc(),
      consentState: consentState,
      birthDate: birthDate?.toUtc(),
    );
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<void> clearSnapshot() {
    return _snapshotStore.deleteIfExists();
  }
}
