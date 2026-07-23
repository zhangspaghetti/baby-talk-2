import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
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
    required this.audioAsset,
  });

  final String spaceId;
  final String activityId;
  final String phraseId;
  final String phraseEnglish;
  final String phraseChinese;
  final String audioAsset;

  String get audioAssetSource =>
      audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset;
}

class OnboardingRepository {
  OnboardingRepository({
    required OnboardingSnapshotStore snapshotStore,
    required OnboardingFlowStore flowStore,
    required PracticeRepository practiceRepository,
    required this.starterSpaceId,
    required this.starterActivityId,
  }) : _snapshotStore = snapshotStore,
       _flowStore = flowStore,
       _practiceRepository = practiceRepository;

  final OnboardingSnapshotStore _snapshotStore;
  final OnboardingFlowStore _flowStore;
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

  Future<OnboardingFlowSnapshot?> readFlowSnapshot() async {
    try {
      return await _flowStore.read();
    } on FormatException {
      await _flowStore.deleteIfExists();
      return null;
    }
  }

  Future<OnboardingFlowSnapshot> saveFlowSnapshot(
    OnboardingFlowSnapshot snapshot,
  ) async {
    await _flowStore.write(snapshot);
    return snapshot;
  }

  Future<void> clearFlowSnapshot() => _flowStore.deleteIfExists();

  Future<void> clearAllLocalState() async {
    await _flowStore.deleteIfExists();
    await _snapshotStore.deleteIfExists();
  }

  Future<OnboardingStarterSeed> resolveStarterSeed() async {
    final activitySnapshot = await _practiceRepository.getActivitySnapshot(
      spaceId: starterSpaceId,
      activityId: starterActivityId,
    );
    if (activitySnapshot.phrases.isEmpty) {
      throw const FormatException('第一句内容不可用：活动缺少可用短语。');
    }

    final starterPhrase = activitySnapshot.phrases.first;
    if (starterPhrase.phraseId.trim().isEmpty ||
        starterPhrase.english.trim().isEmpty) {
      throw const FormatException('第一句内容不可用：短语缺失关键字段。');
    }

    return OnboardingStarterSeed(
      spaceId: activitySnapshot.spaceId,
      activityId: activitySnapshot.activityId,
      phraseId: starterPhrase.phraseId,
      phraseEnglish: starterPhrase.english,
      phraseChinese: starterPhrase.chinese,
      audioAsset: starterPhrase.audioAsset,
    );
  }

  Future<OnboardingSnapshot> saveSnapshot(OnboardingSnapshot snapshot) async {
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<OnboardingSnapshot> completeOnboarding({
    required String childDisplayName,
    required OnboardingAgeBucket ageBucket,
    required List<String> selectedSceneIds,
    required OnboardingSupportGoal supportGoal,
    required String starterSpaceId,
    required String starterActivityId,
    required String starterPhraseId,
    required String firstTraceEventKey,
    OnboardingConsentState consentState = OnboardingConsentState.localOnly,
    DateTime? completedAt,
  }) async {
    final trimmedDisplayName = _requiredTrimmed(childDisplayName, '宝宝昵称');
    final normalizedSceneIds = <String>[];
    final seenSceneIds = <String>{};
    for (final sceneId in selectedSceneIds) {
      final normalizedSceneId = _requiredTrimmed(sceneId, '场景 ID');
      if (seenSceneIds.add(normalizedSceneId)) {
        normalizedSceneIds.add(normalizedSceneId);
      }
    }
    final stageMatch = StageMatchCatalog.forAgeBucket(ageBucket);
    final snapshot = OnboardingSnapshot(
      schemaVersion: 2,
      childDisplayName: trimmedDisplayName,
      ageBucket: ageBucket,
      approxMonths: stageMatch.approxMonths,
      currentStage: stageMatch.stageId,
      starterSpaceId: _requiredTrimmed(starterSpaceId, 'starterSpaceId'),
      starterActivityId: _requiredTrimmed(
        starterActivityId,
        'starterActivityId',
      ),
      starterPhraseId: _requiredTrimmed(starterPhraseId, 'starterPhraseId'),
      selectedSceneIds: normalizedSceneIds,
      supportGoal: supportGoal,
      firstTraceEventKey: _requiredTrimmed(
        firstTraceEventKey,
        'firstTraceEventKey',
      ),
      completedAt: (completedAt ?? DateTime.now()).toUtc(),
      consentState: consentState,
    );
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<OnboardingSnapshot> completeLegacyOnboarding({
    required String childDisplayName,
    required OnboardingAgeBucket ageBucket,
    OnboardingConsentState consentState = OnboardingConsentState.localOnly,
    DateTime? birthDate,
    DateTime? completedAt,
  }) async {
    final stageMatch = StageMatchCatalog.forAgeBucket(ageBucket);
    final starterSeed = await resolveStarterSeed();
    final snapshot = OnboardingSnapshot(
      childDisplayName: _requiredTrimmed(childDisplayName, '宝宝昵称'),
      ageBucket: ageBucket,
      approxMonths: stageMatch.approxMonths,
      currentStage: stageMatch.stageId,
      starterSpaceId: starterSeed.spaceId,
      starterActivityId: starterSeed.activityId,
      starterPhraseId: starterSeed.phraseId,
      consentState: consentState,
      birthDate: birthDate?.toUtc(),
      completedAt: (completedAt ?? DateTime.now()).toUtc(),
    );
    await _snapshotStore.write(snapshot);
    return snapshot;
  }

  Future<void> clearSnapshot() {
    return _snapshotStore.deleteIfExists();
  }

  String _requiredTrimmed(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$fieldName 不能为空。');
    }
    return trimmed;
  }
}
