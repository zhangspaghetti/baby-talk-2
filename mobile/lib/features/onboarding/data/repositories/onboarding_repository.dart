import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingRepository {
  OnboardingRepository({
    required OnboardingSnapshotStore snapshotStore,
    required OnboardingFlowStore flowStore,
  }) : _snapshotStore = snapshotStore,
       _flowStore = flowStore;

  final OnboardingSnapshotStore _snapshotStore;
  final OnboardingFlowStore _flowStore;

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
