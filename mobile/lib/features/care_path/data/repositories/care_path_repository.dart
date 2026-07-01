import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

class CarePathRepository {
  CarePathRepository({
    required PracticeRepository practiceRepository,
    GardenGrowthRepository? gardenGrowthRepository,
  }) : _practiceRepository = practiceRepository,
       _gardenGrowthRepository = gardenGrowthRepository;

  final PracticeRepository _practiceRepository;
  final GardenGrowthRepository? _gardenGrowthRepository;

  Future<CareTurnSnapshot> loadCurrentTurn({
    String? starterSpaceId,
    String? starterActivityId,
  }) async {
    try {
      final continuity = await _practiceRepository.getContinuitySnapshot(
        starterSpaceId: starterSpaceId,
        starterActivityId: starterActivityId,
      );
      final activitySummary = continuity.recommendedActivity;
      final activity = await _practiceRepository.getActivitySnapshot(
        spaceId: activitySummary.spaceId,
        activityId: activitySummary.activityId,
      );
      final resumeInfo = await _practiceRepository.getResumeInfo(
        spaceId: activitySummary.spaceId,
        activityId: activitySummary.activityId,
      );

      final snapshot = _buildTurnSnapshot(
        activity: activity,
        summary: activitySummary,
        nextPhraseId: resumeInfo.nextPhraseId,
        nodeState: activitySummary.isComplete
            ? CarePathNodeState.doneToday
            : CarePathNodeState.current,
        warningMessage: continuity.warningMessage,
      );
      return snapshot;
    } catch (error) {
      return _unavailableSnapshot(
        spaceId: starterSpaceId,
        activityId: starterActivityId,
        message: 'care path 暂时无法读取当前节点：$error',
      );
    }
  }

  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async {
    try {
      final catalog = await _practiceRepository.getActivityCatalog();
      final activitySummary = catalog.findActivity(
        spaceId: spaceId,
        activityId: activityId,
      );
      final activity = await _practiceRepository.getActivitySnapshot(
        spaceId: spaceId,
        activityId: activityId,
      );
      final resumeInfo = await _practiceRepository.getResumeInfo(
        spaceId: spaceId,
        activityId: activityId,
      );

      final snapshot = _buildTurnSnapshot(
        activity: activity,
        summary: activitySummary,
        nextPhraseId: resumeInfo.nextPhraseId,
        nodeState: activitySummary?.isComplete ?? false
            ? CarePathNodeState.doneToday
            : CarePathNodeState.current,
        warningMessage: activitySummary?.warningMessage,
      );
      if (snapshot.currentUtterance == null) {
        return snapshot;
      }
      return snapshot.copyWith(
        phase: CareTurnPhase.utteranceReady,
        selectedReaction: null,
        nextSupportUtterance: null,
        traceEventKey: null,
        latestGardenImpact: null,
      );
    } catch (error) {
      return _unavailableSnapshot(
        spaceId: spaceId,
        activityId: activityId,
        message: 'care path 暂时无法开始这个节点：$error',
      );
    }
  }

  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final utterance = turn.currentUtterance;
    if (utterance == null) {
      return turn.copyWith(
        phase: CareTurnPhase.heldWithFallback,
        selectedReaction: reactionType,
        message: '当前节点没有可记录的 utterance，已保留在安全状态。',
      );
    }

    try {
      final event = await _practiceRepository.recordReaction(
        spaceId: turn.moment.spaceId,
        activityId: turn.moment.activityId,
        phraseId: utterance.phraseId,
        reactionType: reactionType,
        clientTimestamp: clientTimestamp,
        localEventId: localEventId,
      );
      final nextTurn = await startMoment(
        spaceId: turn.moment.spaceId,
        activityId: turn.moment.activityId,
      );
      final latestGardenImpact = await _loadLatestGardenImpact();
      if (nextTurn.currentUtterance == null) {
        return turn.copyWith(
          selectedReaction: reactionType,
          nextSupportUtterance: null,
          phase: CareTurnPhase.heldWithFallback,
          traceEventKey: event.eventKey,
          latestGardenImpact: latestGardenImpact,
          message: nextTurn.message,
        );
      }

      return turn.copyWith(
        selectedReaction: reactionType,
        nextSupportUtterance: nextTurn.currentUtterance,
        phase: CareTurnPhase.nextSupportReady,
        traceEventKey: event.eventKey,
        latestGardenImpact: latestGardenImpact,
        message: nextTurn.message,
      );
    } catch (error) {
      return turn.copyWith(
        phase: CareTurnPhase.error,
        selectedReaction: reactionType,
        message: 'care path 暂时无法记录这次回应：$error',
      );
    }
  }

  Future<LatestPracticeImpact?> _loadLatestGardenImpact() async {
    final gardenGrowthRepository = _gardenGrowthRepository;
    if (gardenGrowthRepository == null) {
      return null;
    }

    try {
      final snapshot = await gardenGrowthRepository.buildSnapshot();
      return snapshot.latestImpact;
    } catch (_) {
      return null;
    }
  }

  CareTurnSnapshot _buildTurnSnapshot({
    required PracticeActivitySnapshot activity,
    required PracticeCatalogActivitySummary? summary,
    required String? nextPhraseId,
    required CarePathNodeState nodeState,
    String? warningMessage,
  }) {
    final utterance =
        nodeState == CarePathNodeState.doneToday && nextPhraseId == null
        ? null
        : _selectUtterance(
            phrases: activity.phrases,
            nextPhraseId: nextPhraseId,
            coachTip: activity.coachTip,
          );
    final isUnavailable = utterance == null;
    final effectiveNodeState = isUnavailable
        ? CarePathNodeState.unavailable
        : nodeState;
    final messageParts = <String>[
      if (warningMessage != null && warningMessage.trim().isNotEmpty)
        warningMessage.trim(),
      if (activity.phrases.isEmpty) '当前节点没有可用 utterance，已保留在安全状态。',
      if (activity.phrases.isNotEmpty &&
          nodeState == CarePathNodeState.doneToday &&
          nextPhraseId == null)
        '当前节点今天已经完成，先停在安全状态。',
    ];

    return CareTurnSnapshot(
      moment: _buildMoment(
        activity: activity,
        summary: summary,
        nodeState: effectiveNodeState,
      ),
      currentUtterance: utterance,
      selectedReaction: null,
      nextSupportUtterance: null,
      phase: utterance == null
          ? CareTurnPhase.heldWithFallback
          : CareTurnPhase.reactionPrompt,
      traceEventKey: null,
      latestGardenImpact: null,
      message: messageParts.isEmpty ? null : messageParts.join('；'),
    );
  }

  CareMoment _buildMoment({
    required PracticeActivitySnapshot activity,
    required PracticeCatalogActivitySummary? summary,
    required CarePathNodeState nodeState,
  }) {
    return CareMoment(
      spaceId: activity.spaceId,
      activityId: activity.activityId,
      spaceTitle: summary?.spaceTitle ?? activity.spaceId,
      title: activity.title,
      sceneTag: activity.sceneTag,
      careActionLabel: activity.summary,
      coachTip: activity.coachTip,
      nodeState: nodeState,
    );
  }

  CareUtterance? _selectUtterance({
    required List<PracticePhrase> phrases,
    required String? nextPhraseId,
    required String coachTip,
  }) {
    if (phrases.isEmpty) {
      return null;
    }
    PracticePhrase selectedPhrase = phrases.first;
    if (nextPhraseId != null) {
      for (final phrase in phrases) {
        if (phrase.phraseId == nextPhraseId) {
          selectedPhrase = phrase;
          break;
        }
      }
    }

    return CareUtterance(
      phraseId: selectedPhrase.phraseId,
      english: selectedPhrase.english,
      chinese: selectedPhrase.chinese,
      pronunciation: selectedPhrase.pronunciation,
      audioAsset: selectedPhrase.audioAsset.trim().isEmpty
          ? null
          : selectedPhrase.audioAsset,
      whenToSay: coachTip,
      isFallback: false,
    );
  }

  CareTurnSnapshot _unavailableSnapshot({
    required String? spaceId,
    required String? activityId,
    required String message,
  }) {
    final effectiveSpaceId = _cleanIdentifier(spaceId) ?? 'unavailable_space';
    final effectiveActivityId =
        _cleanIdentifier(activityId) ?? 'unavailable_activity';

    return CareTurnSnapshot(
      moment: CareMoment(
        spaceId: effectiveSpaceId,
        activityId: effectiveActivityId,
        spaceTitle: effectiveSpaceId,
        title: effectiveActivityId,
        sceneTag: '',
        careActionLabel: '',
        coachTip: '',
        nodeState: CarePathNodeState.unavailable,
      ),
      currentUtterance: null,
      selectedReaction: null,
      nextSupportUtterance: null,
      phase: CareTurnPhase.error,
      traceEventKey: null,
      latestGardenImpact: null,
      message: message,
    );
  }

  String? _cleanIdentifier(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
