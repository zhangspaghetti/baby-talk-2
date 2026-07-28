import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

typedef CarePathReactionRecordedHook =
    Future<void> Function(InteractionEventPayload event);

/// Signals a response which was durably recorded but deliberately withheld.
///
/// The only caller is the debug/profile UAT harness. Production repository
/// behavior never creates this exception.
class CarePathResponseLostException implements Exception {
  const CarePathResponseLostException();
}

class CarePathRepository {
  CarePathRepository({
    required PracticeRepository practiceRepository,
    GardenGrowthRepository? gardenGrowthRepository,
    CarePathReactionRecordedHook? onReactionRecorded,
  }) : _practiceRepository = practiceRepository,
       _gardenGrowthRepository = gardenGrowthRepository,
       _onReactionRecorded = onReactionRecorded;

  final PracticeRepository _practiceRepository;
  final GardenGrowthRepository? _gardenGrowthRepository;
  final CarePathReactionRecordedHook? _onReactionRecorded;

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
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: starterSpaceId,
        activityId: starterActivityId,
        message: '当前照护内容暂时不可用。',
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
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: spaceId,
        activityId: activityId,
        message: '当前照护内容暂时不可用。',
      );
    }
  }

  Future<CareTurnSnapshot> startGeneratedMoment({
    required String generatedContentId,
  }) async {
    try {
      final activity = await _practiceRepository.getGeneratedActivitySnapshot(
        generatedContentId: generatedContentId,
      );
      final resumeInfo = await _practiceRepository.getResumeInfo(
        spaceId: activity.spaceId,
        activityId: activity.activityId,
      );
      final snapshot = _buildTurnSnapshot(
        activity: activity,
        summary: null,
        nextPhraseId: resumeInfo.nextPhraseId,
        nodeState: CarePathNodeState.current,
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
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: null,
        activityId: null,
        message: '当前照护内容暂时不可用。',
        generatedContentId: generatedContentId,
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
        message: '当前照护内容暂时无法记录回应。',
        failureKind: CareTurnFailureKind.reactionRejected,
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
      await _onReactionRecorded?.call(event);
      final isGenerated =
          turn.moment.contentSource == PracticeContentSource.generated;
      late final CareUtterance? nextSupport;
      String? nextMessage;
      if (isGenerated) {
        nextSupport = await _loadGeneratedReactionSupport(
          turn: turn,
          reactionType: reactionType,
        );
      } else {
        final nextTurn = await startMoment(
          spaceId: turn.moment.spaceId,
          activityId: turn.moment.activityId,
        );
        nextSupport = nextTurn.currentUtterance;
        nextMessage = nextTurn.message;
      }
      final latestGardenImpact = await _loadLatestGardenImpact();
      if (nextSupport == null) {
        return turn.copyWith(
          selectedReaction: reactionType,
          nextSupportUtterance: null,
          phase: CareTurnPhase.heldWithFallback,
          traceEventKey: event.eventKey,
          latestGardenImpact: latestGardenImpact,
          message: isGenerated ? '刚才这句话已经记下了。下一句暂时没有准备好，先这样就好。' : nextMessage,
        );
      }

      return turn.copyWith(
        selectedReaction: reactionType,
        nextSupportUtterance: nextSupport,
        phase: CareTurnPhase.nextSupportReady,
        traceEventKey: event.eventKey,
        latestGardenImpact: latestGardenImpact,
        message: nextMessage,
      );
    } on CarePathResponseLostException {
      return turn.copyWith(
        phase: CareTurnPhase.error,
        selectedReaction: reactionType,
        message: '刚才的回应可能已经保存，正在确认。请再试一次。',
        failureKind: CareTurnFailureKind.reactionUnknownOutcome,
      );
    } catch (_) {
      return turn.copyWith(
        phase: CareTurnPhase.error,
        selectedReaction: reactionType,
        message: '暂时无法完成这次回应，请再试一次。',
        failureKind: CareTurnFailureKind.reactionUnknownOutcome,
      );
    }
  }

  Future<CareTurnSnapshot> restorePendingReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
  }) async {
    try {
      final catalog = await _practiceRepository.getActivityCatalog();
      final summary = catalog.findActivity(
        spaceId: spaceId,
        activityId: activityId,
      );
      final activity = await _practiceRepository.getActivitySnapshot(
        spaceId: spaceId,
        activityId: activityId,
      );
      final utterance = _utteranceForPhrase(
        activity: activity,
        phraseId: phraseId,
        coachTip: activity.coachTip,
      );
      if (utterance == null) {
        return _unavailableSnapshot(
          spaceId: spaceId,
          activityId: activityId,
          message: '当前照护内容暂时无法恢复。',
        );
      }

      return CareTurnSnapshot(
        moment: _buildMoment(
          activity: activity,
          summary: summary,
          nodeState: CarePathNodeState.current,
        ),
        currentUtterance: utterance,
        selectedReaction: reactionType,
        nextSupportUtterance: null,
        phase: CareTurnPhase.reactionPrompt,
        traceEventKey: null,
        latestGardenImpact: null,
        message: null,
      );
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: spaceId,
        activityId: activityId,
        message: '当前照护内容暂时无法恢复。',
      );
    }
  }

  Future<CareTurnSnapshot> restoreConfirmedReaction(
    InteractionEventPayload event,
  ) async {
    try {
      final catalog = await _practiceRepository.getActivityCatalog();
      final summary = catalog.findActivity(
        spaceId: event.spaceId,
        activityId: event.activityId,
      );
      final activity = await _practiceRepository.getActivitySnapshot(
        spaceId: event.spaceId,
        activityId: event.activityId,
      );
      final utterance = _utteranceForPhrase(
        activity: activity,
        phraseId: event.phraseId,
        coachTip: activity.coachTip,
      );
      if (utterance == null) {
        return _unavailableSnapshot(
          spaceId: event.spaceId,
          activityId: event.activityId,
          message: '刚才的照护记录已保存，但内容暂时无法恢复。',
        );
      }

      final nextTurn = await startMoment(
        spaceId: event.spaceId,
        activityId: event.activityId,
      );
      final latestGardenImpact = await _loadLatestGardenImpact();
      return CareTurnSnapshot(
        moment: _buildMoment(
          activity: activity,
          summary: summary,
          nodeState: CarePathNodeState.current,
        ),
        currentUtterance: utterance,
        selectedReaction: event.reactionType,
        nextSupportUtterance: nextTurn.currentUtterance,
        phase: nextTurn.currentUtterance == null
            ? CareTurnPhase.heldWithFallback
            : CareTurnPhase.nextSupportReady,
        traceEventKey: event.eventKey,
        latestGardenImpact: latestGardenImpact,
        message: nextTurn.currentUtterance == null
            ? '刚才这句话已经记下了。下一句暂时没有准备好，先这样就好。'
            : nextTurn.message,
      );
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: event.spaceId,
        activityId: event.activityId,
        message: '刚才的照护记录已保存，但暂时无法恢复。',
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

  Future<CareUtterance?> _loadGeneratedReactionSupport({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
  }) async {
    final generatedContentId = turn.moment.generatedContentId;
    if (generatedContentId == null) {
      return null;
    }
    final activity = await _practiceRepository.getGeneratedActivitySnapshot(
      generatedContentId: generatedContentId,
    );
    final phraseId = activity.reactionSupportPhraseId(reactionType);
    if (phraseId == null) {
      return null;
    }
    return _utteranceForPhrase(
      activity: activity,
      phraseId: phraseId,
      coachTip: activity.coachTip,
    );
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
            activity: activity,
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
      if (activity.phrases.isEmpty) '当前照护内容暂时不可用。',
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
      contentSource: activity.contentSource,
      generatedContentId: activity.generatedContentId,
    );
  }

  CareUtterance? _selectUtterance({
    required PracticeActivitySnapshot activity,
    required String? nextPhraseId,
    required String coachTip,
  }) {
    final phrases = activity.phrases;
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

    return _toCareUtterance(
      activity: activity,
      phrase: selectedPhrase,
      coachTip: coachTip,
    );
  }

  CareUtterance? _utteranceForPhrase({
    required PracticeActivitySnapshot activity,
    required String phraseId,
    required String coachTip,
  }) {
    final phrases = activity.phrases;
    for (final phrase in phrases) {
      if (phrase.phraseId == phraseId) {
        return _toCareUtterance(
          activity: activity,
          phrase: phrase,
          coachTip: coachTip,
        );
      }
    }
    return null;
  }

  CareUtterance _toCareUtterance({
    required PracticeActivitySnapshot? activity,
    required PracticePhrase phrase,
    required String coachTip,
  }) {
    final generatedContentId = activity?.generatedContentId;
    final utteranceId = activity?.utteranceIdForPhrase(phrase.phraseId);
    return CareUtterance(
      phraseId: phrase.phraseId,
      english: phrase.english,
      chinese: phrase.chinese,
      pronunciation: phrase.pronunciation,
      audioAsset: phrase.audioAsset.trim().isEmpty ? null : phrase.audioAsset,
      whenToSay: coachTip,
      isFallback: false,
      audioSource:
          activity?.contentSource == PracticeContentSource.generated &&
              generatedContentId != null &&
              utteranceId != null
          ? GeneratedCareAudioSource(
              generatedContentId: generatedContentId,
              utteranceId: utteranceId,
            )
          : null,
    );
  }

  CareTurnSnapshot _unavailableSnapshot({
    required String? spaceId,
    required String? activityId,
    required String message,
    CareTurnFailureKind failureKind = CareTurnFailureKind.momentUnavailable,
    String? generatedContentId,
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
        contentSource: generatedContentId == null
            ? PracticeContentSource.seed
            : PracticeContentSource.generated,
        generatedContentId: generatedContentId,
      ),
      currentUtterance: null,
      selectedReaction: null,
      nextSupportUtterance: null,
      phase: CareTurnPhase.error,
      traceEventKey: null,
      latestGardenImpact: null,
      message: message,
      failureKind: failureKind,
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
