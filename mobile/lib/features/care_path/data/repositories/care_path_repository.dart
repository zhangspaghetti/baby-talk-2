import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
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
    OnboardingCareTurnContinuationPort? onboardingContinuationPort,
  }) : _practiceRepository = practiceRepository,
       _gardenGrowthRepository = gardenGrowthRepository,
       _onReactionRecorded = onReactionRecorded,
       _onboardingContinuationPort = onboardingContinuationPort;

  final PracticeRepository _practiceRepository;
  final GardenGrowthRepository? _gardenGrowthRepository;
  final CarePathReactionRecordedHook? _onReactionRecorded;
  final OnboardingCareTurnContinuationPort? _onboardingContinuationPort;

  Future<CareTurnSnapshot> startContinuation(
    OnboardingCareTurnHandoff handoff,
  ) async {
    try {
      final port = _onboardingContinuationPort;
      if (port == null) {
        throw StateError('onboarding continuation port 未配置。');
      }
      final verified = await port.verify(handoff);
      final activity = await _loadBundledActivitySnapshot(
        spaceId: verified.spaceId,
        activityId: verified.activityId,
      );
      if (activity.spaceId != verified.spaceId ||
          activity.activityId != verified.activityId) {
        throw const FormatException('onboarding continuation scope 不匹配。');
      }
      return CareTurnSnapshot(
        moment: _buildMoment(
          activity: activity,
          summary: null,
          nodeState: CarePathNodeState.current,
        ).copyWith(title: verified.entryTitle),
        currentUtterance: CareUtterance(
          phraseId: verified.utteranceId,
          english: verified.english,
          chinese: verified.chinese,
          pronunciation: '',
          audioAsset: null,
          whenToSay: '接着刚才，轻轻说这一句。',
          isFallback: verified.source == OnboardingCareTurnSource.localFallback,
          sourceIdentity: verified.source.wireValue,
        ),
        selectedReaction: null,
        nextSupportUtterance: null,
        phase: CareTurnPhase.utteranceReady,
        traceEventKey: null,
        latestGardenImpact: null,
        message: null,
        onboardingContinuation: verified,
        bundledOnly: true,
      );
    } catch (_) {
      return _unavailableSnapshot(
        spaceId: handoff.spaceId,
        activityId: handoff.activityId,
        message: '刚才的下一句暂时无法核验，请返回今天重试。',
        bundledOnly: true,
      );
    }
  }

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
      final activity = activitySummary.generatedContentId == null
          ? await _practiceRepository.getActivitySnapshot(
              spaceId: activitySummary.spaceId,
              activityId: activitySummary.activityId,
            )
          : await _practiceRepository.getGeneratedActivitySnapshot(
              generatedContentId: activitySummary.generatedContentId!,
            );
      final resumeInfo = activitySummary.generatedContentId == null
          ? await _practiceRepository.getResumeInfo(
              spaceId: activitySummary.spaceId,
              activityId: activitySummary.activityId,
            )
          : await _practiceRepository.getGeneratedResumeInfo(
              generatedContentId: activitySummary.generatedContentId!,
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
    bool bundledOnly = false,
  }) async {
    if (bundledOnly) {
      try {
        return await _startBundledMoment(
          spaceId: spaceId,
          activityId: activityId,
        );
      } catch (_) {
        return _unavailableSnapshot(
          spaceId: spaceId,
          activityId: activityId,
          message: '当前通用照护内容暂时不可用。',
          bundledOnly: true,
        );
      }
    }
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
      final resumeInfo = await _practiceRepository.getGeneratedResumeInfo(
        generatedContentId: generatedContentId,
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
    final continuation = turn.onboardingContinuation;
    if (continuation != null) {
      return _recordContinuationReaction(
        turn: turn,
        handoff: continuation,
        reactionType: reactionType,
        clientTimestamp: clientTimestamp,
      );
    }
    final isGenerated =
        turn.moment.contentSource == PracticeContentSource.generated;
    final generatedAudio = utterance.audioSource;
    if (isGenerated &&
        (turn.moment.generatedContentId == null ||
            generatedAudio is! GeneratedCareAudioSource)) {
      return turn.copyWith(
        phase: CareTurnPhase.heldWithFallback,
        selectedReaction: reactionType,
        message: '当前照护内容缺少可核验 identity，未写入回应。',
        failureKind: CareTurnFailureKind.reactionRejected,
      );
    }

    try {
      final event = await _recordReaction(
        spaceId: turn.moment.spaceId,
        activityId: turn.moment.activityId,
        phraseId: utterance.phraseId,
        reactionType: reactionType,
        generatedContentId: isGenerated ? turn.moment.generatedContentId : null,
        utteranceId: isGenerated
            ? (generatedAudio as GeneratedCareAudioSource).utteranceId
            : null,
        clientTimestamp: clientTimestamp,
        localEventId: localEventId,
        bundledOnly: turn.bundledOnly,
      );
      await _onReactionRecorded?.call(event);
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
          bundledOnly: turn.bundledOnly,
        );
        nextSupport = nextTurn.currentUtterance;
        nextMessage = nextTurn.message;
      }
      final latestGardenImpact = turn.bundledOnly
          ? null
          : await _loadLatestGardenImpact();
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
      final utteranceState = _reactionUtteranceState(
        isGenerated: isGenerated,
        currentUtterance: utterance,
        matchingSupport: nextSupport,
      );

      return turn.copyWith(
        currentUtterance: utteranceState.currentUtterance,
        selectedReaction: reactionType,
        nextSupportUtterance: utteranceState.nextSupportUtterance,
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

  Future<InteractionEventPayload> _recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    required bool bundledOnly,
    DateTime? clientTimestamp,
    String? localEventId,
    String? generatedContentId,
    String? utteranceId,
  }) {
    if (bundledOnly) {
      return _practiceRepository.recordBundledReaction(
        spaceId: spaceId,
        activityId: activityId,
        phraseId: phraseId,
        reactionType: reactionType,
        clientTimestamp: clientTimestamp,
        localEventId: localEventId,
      );
    }
    return _practiceRepository.recordReaction(
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      generatedContentId: generatedContentId,
      utteranceId: utteranceId,
      clientTimestamp: clientTimestamp,
      localEventId: localEventId,
    );
  }

  Future<CareTurnSnapshot> _recordContinuationReaction({
    required CareTurnSnapshot turn,
    required OnboardingCareTurnHandoff handoff,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
  }) async {
    final port = _onboardingContinuationPort;
    if (port == null) {
      return turn.copyWith(
        phase: CareTurnPhase.error,
        selectedReaction: reactionType,
        message: '暂时无法完成这次回应，请再试一次。',
        failureKind: CareTurnFailureKind.localStateUnavailable,
      );
    }
    try {
      final record = await port.recordReaction(
        handoff: handoff,
        reaction: reactionType.wireValue,
        occurredAt: (clientTimestamp ?? DateTime.now()).toUtc(),
      );
      final nextTurn = await _startBundledMoment(
        spaceId: handoff.spaceId,
        activityId: handoff.activityId,
      );
      final nextSupport = nextTurn.currentUtterance;
      return turn.copyWith(
        selectedReaction: reactionType,
        nextSupportUtterance: nextSupport,
        phase: nextSupport == null
            ? CareTurnPhase.heldWithFallback
            : CareTurnPhase.nextSupportReady,
        traceEventKey: record.eventId,
        // Onboarding continuation is a static seed path. Garden projection
        // remains a signed-in catalog concern and must not trigger a remote
        // or cache read here.
        latestGardenImpact: null,
        message: nextSupport == null ? '刚才这句话已经记下了。下一句暂时没有准备好，先这样就好。' : null,
        failureKind: null,
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
      final isGenerated = event.generatedContentId != null;
      final summary = isGenerated
          ? null
          : (await _practiceRepository.getActivityCatalog()).findActivity(
              spaceId: event.spaceId,
              activityId: event.activityId,
            );
      final activity = isGenerated
          ? await _practiceRepository.getGeneratedActivitySnapshot(
              generatedContentId: event.generatedContentId!,
            )
          : await _practiceRepository.getActivitySnapshot(
              spaceId: event.spaceId,
              activityId: event.activityId,
            );
      if (isGenerated &&
          (activity.spaceId != event.spaceId ||
              activity.activityId != event.activityId ||
              activity.generatedContentId != event.generatedContentId ||
              activity.utteranceIdForPhrase(event.phraseId) !=
                  event.utteranceId)) {
        return _unavailableSnapshot(
          spaceId: event.spaceId,
          activityId: event.activityId,
          generatedContentId: event.generatedContentId,
          message: '刚才的照护记录已保存，但内容 identity 无法核验。',
        );
      }
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

      final generatedTurn = CareTurnSnapshot(
        moment: _buildMoment(
          activity: activity,
          summary: summary,
          nodeState: CarePathNodeState.current,
        ),
        currentUtterance: utterance,
        selectedReaction: event.reactionType,
        nextSupportUtterance: null,
        phase: CareTurnPhase.reactionPrompt,
        traceEventKey: event.eventKey,
        latestGardenImpact: null,
        message: null,
      );
      final nextSupport = isGenerated
          ? await _loadGeneratedReactionSupport(
              turn: generatedTurn,
              reactionType: event.reactionType,
            )
          : (await startMoment(
              spaceId: event.spaceId,
              activityId: event.activityId,
            )).currentUtterance;
      final latestGardenImpact = await _loadLatestGardenImpact();
      final utteranceState = _reactionUtteranceState(
        isGenerated: isGenerated,
        currentUtterance: utterance,
        matchingSupport: nextSupport,
      );
      return CareTurnSnapshot(
        moment: _buildMoment(
          activity: activity,
          summary: summary,
          nodeState: CarePathNodeState.current,
        ),
        currentUtterance: utteranceState.currentUtterance,
        selectedReaction: event.reactionType,
        nextSupportUtterance: utteranceState.nextSupportUtterance,
        phase: nextSupport == null
            ? CareTurnPhase.heldWithFallback
            : CareTurnPhase.nextSupportReady,
        traceEventKey: event.eventKey,
        latestGardenImpact: latestGardenImpact,
        message: nextSupport == null ? '刚才这句话已经记下了。下一句暂时没有准备好，先这样就好。' : null,
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

  Future<CareTurnSnapshot> _startBundledMoment({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await _loadBundledActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    if (activity.contentSource != PracticeContentSource.seed ||
        activity.generatedContentId != null) {
      throw const FormatException('bundled fallback content source is invalid');
    }
    final snapshot = _buildTurnSnapshot(
      activity: activity,
      summary: null,
      nextPhraseId: null,
      nodeState: CarePathNodeState.current,
      bundledOnly: true,
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
  }

  Future<PracticeActivitySnapshot> _loadBundledActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) => _practiceRepository.getBundledActivitySnapshot(
    spaceId: spaceId,
    activityId: activityId,
  );

  ({CareUtterance currentUtterance, CareUtterance? nextSupportUtterance})
  _reactionUtteranceState({
    required bool isGenerated,
    required CareUtterance currentUtterance,
    required CareUtterance? matchingSupport,
  }) {
    if (!isGenerated || matchingSupport == null) {
      return (
        currentUtterance: currentUtterance,
        nextSupportUtterance: matchingSupport,
      );
    }
    return (currentUtterance: matchingSupport, nextSupportUtterance: null);
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
    bool bundledOnly = false,
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
      bundledOnly: bundledOnly,
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
          : phrase.audioAsset.trim().isEmpty
          ? null
          : CareAssetAudioSource(assetPath: phrase.audioAsset),
    );
  }

  CareTurnSnapshot _unavailableSnapshot({
    required String? spaceId,
    required String? activityId,
    required String message,
    CareTurnFailureKind failureKind = CareTurnFailureKind.momentUnavailable,
    String? generatedContentId,
    bool bundledOnly = false,
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
      bundledOnly: bundledOnly,
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
