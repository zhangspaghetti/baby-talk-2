import 'dart:async';
import 'dart:math';

import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

typedef MentorHouseholdSnapshotLoader =
    Future<HouseholdLocalSnapshot> Function();

class MentorFactInspectionIssue {
  const MentorFactInspectionIssue({
    required this.message,
    this.localEventId,
    this.createdAt,
  });

  final String message;
  final String? localEventId;
  final DateTime? createdAt;
}

class MentorFactInspection {
  const MentorFactInspection({
    required this.installationId,
    required this.storedFactCount,
    required this.validFacts,
    required this.skippedFactCount,
    this.lastIssue,
    this.scanErrorMessage,
  });

  final String? installationId;
  final int storedFactCount;
  final List<MentorFactEvent> validFacts;
  final int skippedFactCount;
  final MentorFactInspectionIssue? lastIssue;
  final String? scanErrorMessage;

  int get validFactCount => validFacts.length;
  bool get hasRecoverableIssue =>
      skippedFactCount > 0 || scanErrorMessage != null;
}

class MentorRepository {
  MentorRepository({
    required MentorLocalDataSource localDataSource,
    required PracticeRepository practiceRepository,
    required OnboardingSnapshotStore onboardingSnapshotStore,
    LocalMentorSuggestionService? suggestionService,
    MentorHouseholdSnapshotLoader? householdSnapshotLoader,
    Random? random,
  }) : _localDataSource = localDataSource,
       _practiceRepository = practiceRepository,
       _onboardingSnapshotStore = onboardingSnapshotStore,
       _suggestionService =
           suggestionService ?? const LocalMentorSuggestionService(),
       _householdSnapshotLoader = householdSnapshotLoader,
       _random = random ?? Random();

  final MentorLocalDataSource _localDataSource;
  final PracticeRepository _practiceRepository;
  final OnboardingSnapshotStore _onboardingSnapshotStore;
  final LocalMentorSuggestionService _suggestionService;
  final MentorHouseholdSnapshotLoader? _householdSnapshotLoader;
  final Random _random;
  bool _isClosed = false;

  Future<String> ensureInstallationId() {
    return _practiceRepository.ensureInstallationId();
  }

  Future<String?> readExistingInstallationId() {
    return _practiceRepository.readExistingInstallationId();
  }

  Future<MentorFactEvent> appendFact({
    required MentorFactType eventType,
    required String phase,
    DateTime? createdAt,
    String? localEventId,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) async {
    final payload = MentorFactEvent(
      localEventId: localEventId ?? _generateLocalEventId(),
      installationId: await _practiceRepository.ensureInstallationId(),
      eventType: eventType,
      phase: phase,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      correlationId: correlationId,
      redactedSummary: redactedSummary,
      visibleStatus: visibleStatus,
      visibleDetail: visibleDetail,
      retryable: retryable,
      contextFallbackUsed: contextFallbackUsed,
    );
    await _localDataSource.appendMentorFactEvent(payload);
    return payload;
  }

  Future<List<MentorFactEvent>> listFactHistory({
    MentorFactType? eventType,
    int? limit,
  }) {
    return _localDataSource.listMentorFactEvents(
      eventType: eventType,
      limit: limit,
    );
  }

  Future<MentorFactInspection> inspectFactLog() async {
    final installationId = await _practiceRepository
        .readExistingInstallationId();
    try {
      final rawEntities = await _localDataSource.listRawEntities();
      final validFacts = <MentorFactEvent>[];
      var skippedFactCount = 0;
      MentorFactInspectionIssue? lastIssue;

      for (final entity in rawEntities) {
        try {
          validFacts.add(MentorLocalDataSource.payloadFromEntity(entity));
        } catch (error) {
          skippedFactCount += 1;
          lastIssue = MentorFactInspectionIssue(
            localEventId: entity.localEventId,
            createdAt: entity.createdAt,
            message: '$error',
          );
        }
      }

      return MentorFactInspection(
        installationId: installationId,
        storedFactCount: rawEntities.length,
        validFacts: List.unmodifiable(validFacts),
        skippedFactCount: skippedFactCount,
        lastIssue: lastIssue,
      );
    } catch (error) {
      return MentorFactInspection(
        installationId: installationId,
        storedFactCount: 0,
        validFacts: const <MentorFactEvent>[],
        skippedFactCount: 0,
        scanErrorMessage: 'mentor fact 读取失败：$error',
      );
    }
  }

  Future<LocalMentorSuggestionResult> deriveLocalSuggestions() async {
    OnboardingSnapshot? onboardingSnapshot;
    var contextFallbackUsed = false;
    String? fallbackReasonCode;

    try {
      onboardingSnapshot = await _onboardingSnapshotStore.read();
    } on FormatException {
      contextFallbackUsed = true;
      fallbackReasonCode = 'onboarding_malformed';
    } on OnboardingSnapshotPersistenceException {
      contextFallbackUsed = true;
      fallbackReasonCode = 'onboarding_unavailable';
    } catch (_) {
      contextFallbackUsed = true;
      fallbackReasonCode = 'onboarding_unavailable';
    }

    if (onboardingSnapshot == null && fallbackReasonCode == null) {
      contextFallbackUsed = true;
      fallbackReasonCode = 'onboarding_missing';
    }

    final stageId = _normalize(onboardingSnapshot?.currentStage);
    final starterSpaceId = _normalize(onboardingSnapshot?.starterSpaceId);
    final starterActivityId = _normalize(onboardingSnapshot?.starterActivityId);
    final starterPhraseId = _normalize(onboardingSnapshot?.starterPhraseId);

    PracticeContinuitySnapshot? continuitySnapshot;
    if (!contextFallbackUsed) {
      try {
        continuitySnapshot = await _practiceRepository.getContinuitySnapshot(
          starterSpaceId: starterSpaceId,
          starterActivityId: starterActivityId,
        );
      } on TimeoutException {
        contextFallbackUsed = true;
        fallbackReasonCode = 'continuity_timeout';
      } on FormatException {
        contextFallbackUsed = true;
        fallbackReasonCode = 'continuity_malformed';
      } catch (_) {
        contextFallbackUsed = true;
        fallbackReasonCode = 'continuity_failed';
      }
    }

    var continuityContext = const _MentorContinuityContext();
    if (!contextFallbackUsed && continuitySnapshot != null) {
      continuityContext = _mapContinuityContext(continuitySnapshot);
    }

    final sharedResolution = await _resolveSharedContext(
      stageId: stageId,
      localContextFallbackUsed: contextFallbackUsed,
      continuityContext: continuityContext,
    );
    if (sharedResolution.adoptedResult != null) {
      return sharedResolution.adoptedResult!;
    }

    PracticeActivitySnapshot? starterActivitySnapshot;
    if (!contextFallbackUsed && continuityContext.recentPractice == null) {
      if (starterSpaceId == null ||
          starterActivityId == null ||
          starterPhraseId == null) {
        contextFallbackUsed = true;
        fallbackReasonCode = 'starter_seed_missing';
      } else {
        try {
          starterActivitySnapshot = await _practiceRepository
              .getActivitySnapshot(
                spaceId: starterSpaceId,
                activityId: starterActivityId,
              );
        } on TimeoutException {
          contextFallbackUsed = true;
          fallbackReasonCode = 'starter_activity_timeout';
        } on FormatException {
          contextFallbackUsed = true;
          fallbackReasonCode = 'starter_activity_invalid';
        } catch (_) {
          contextFallbackUsed = true;
          fallbackReasonCode = 'starter_activity_unavailable';
        }
      }
    }

    final suggestionContext = LocalMentorSuggestionContext(
      stageId: stageId,
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
      starterPhraseId: starterPhraseId,
      activityTitle: starterActivitySnapshot?.title,
      activitySummary: starterActivitySnapshot?.summary,
      coachTip: starterActivitySnapshot?.coachTip,
      sceneTag: starterActivitySnapshot?.sceneTag,
      phrases:
          starterActivitySnapshot?.phrases
              .map(
                (phrase) => LocalMentorPracticePhraseContext(
                  phraseId: phrase.phraseId,
                  english: phrase.english,
                  chinese: phrase.chinese,
                  step: phrase.step,
                ),
              )
              .toList(growable: false) ??
          const <LocalMentorPracticePhraseContext>[],
      recentPractice: contextFallbackUsed
          ? null
          : continuityContext.recentPractice,
      contextFallbackUsed: contextFallbackUsed,
      fallbackReasonCode: contextFallbackUsed
          ? fallbackReasonCode
          : continuityContext.fallbackReasonCode,
    );

    final result = _suggestionService.derive(suggestionContext);
    return _withSharedContextStatus(result, sharedResolution.status);
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    await _localDataSource.close(deleteFromDisk: deleteFromDisk);
  }

  _MentorContinuityContext _mapContinuityContext(
    PracticeContinuitySnapshot snapshot,
  ) {
    final recommendationReason = snapshot.recommendation.reason;
    final recentActivity =
        snapshot.recentActivity ?? snapshot.recommendedActivity;
    final latestEventTime =
        recentActivity.recentResult?.eventTime ?? recentActivity.lastEventTime;
    if (recommendationReason != PracticeContinuityReason.recentActivity) {
      return _MentorContinuityContext(
        fallbackReasonCode: recommendationReason.wireValue,
        latestEventTime: latestEventTime,
      );
    }

    final recentResult = recentActivity.recentResult;
    if (recentResult == null) {
      return _MentorContinuityContext(
        fallbackReasonCode: 'recent_context_missing',
        latestEventTime: recentActivity.lastEventTime,
      );
    }

    final activityId = _normalize(recentActivity.activityId);
    final activityTitle = _normalize(recentActivity.title);
    final phraseId = _normalize(recentResult.phraseId);
    final phraseEnglish = _normalize(recentResult.phraseEnglish);
    if (activityId == null ||
        activityTitle == null ||
        phraseId == null ||
        phraseEnglish == null) {
      return _MentorContinuityContext(
        fallbackReasonCode: 'recent_context_unmapped',
        latestEventTime: recentResult.eventTime,
      );
    }

    return _MentorContinuityContext(
      recentPractice: LocalMentorRecentPracticeContext(
        activityId: activityId,
        activityTitle: activityTitle,
        phraseId: phraseId,
        phraseEnglish: phraseEnglish,
        reactionType: recentResult.reactionType,
        totalEvents: recentResult.totalEvents,
      ),
      latestEventTime: recentResult.eventTime,
    );
  }

  Future<_SharedContextResolution> _resolveSharedContext({
    required String? stageId,
    required bool localContextFallbackUsed,
    required _MentorContinuityContext continuityContext,
  }) async {
    final loader = _householdSnapshotLoader;
    if (loader == null) {
      return const _SharedContextResolution();
    }

    HouseholdLocalSnapshot snapshot;
    try {
      snapshot = await loader();
    } on FormatException {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_snapshot_malformed',
          detail: '共享 household 快照已损坏，Mentor 继续使用本地建议。',
        ),
      );
    } catch (_) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_snapshot_unavailable',
          detail: '共享 household 快照暂时不可读，Mentor 继续使用本地建议。',
        ),
      );
    }

    final sharedContext = snapshot.sharedContext;
    if (sharedContext == null) {
      return _SharedContextResolution(
        status: _sharedStatusFromSnapshot(snapshot),
      );
    }

    final actor = sharedContext.actor;
    if (actor == null) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_actor_missing',
          detail: '共享归因缺少结构化 actor，Mentor 继续使用本地建议。',
        ),
      );
    }
    if (!_isSupportedActorRole(actor.role)) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_actor_unknown',
          detail: '共享归因角色暂不可识别，Mentor 继续使用本地建议。',
        ),
      );
    }

    final safeArgs = _safeNextStepArgs(sharedContext);
    if (safeArgs == null) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_next_step_missing',
          detail: '共享下一步缺少安全 route args，Mentor 继续使用本地建议。',
        ),
      );
    }

    final shouldAdopt =
        localContextFallbackUsed || continuityContext.recentPractice == null
        ? true
        : (continuityContext.latestEventTime == null ||
              sharedContext.latestInteractionAt.isAfter(
                continuityContext.latestEventTime!,
              ));
    if (!shouldAdopt) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_context_skipped_local_newer',
          detail: '本机 continuity 更新更近，Mentor 保持本地建议。',
        ),
      );
    }

    final decisionCode =
        localContextFallbackUsed || continuityContext.recentPractice == null
        ? 'shared_context_adopted_local_gap'
        : 'shared_context_adopted_newer';

    try {
      final activitySnapshot = await _practiceRepository.getActivitySnapshot(
        spaceId: safeArgs.spaceId,
        activityId: safeArgs.activityId,
      );
      return _SharedContextResolution(
        status: _adoptedSharedStatus(
          code: decisionCode,
          actorRole: actor.role,
          activityTitle: activitySnapshot.title,
          nextStepReason: sharedContext.nextStep?.reason,
        ),
        adoptedResult: _buildSharedSuggestionResult(
          stageId: stageId,
          decisionCode: decisionCode,
          sharedContext: sharedContext,
          actor: actor,
          nextStepArgs: safeArgs,
          activitySnapshot: activitySnapshot,
        ),
      );
    } on TimeoutException {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_next_step_timeout',
          detail: '共享下一步活动读取超时，Mentor 继续使用本地建议。',
        ),
      );
    } on FormatException {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_next_step_invalid',
          detail: '共享下一步活动不可用，Mentor 继续使用本地建议。',
        ),
      );
    } catch (_) {
      return _SharedContextResolution(
        status: _skippedSharedStatus(
          code: 'shared_next_step_unavailable',
          detail: '共享下一步活动暂不可读，Mentor 继续使用本地建议。',
        ),
      );
    }
  }

  LocalMentorSuggestionResult _buildSharedSuggestionResult({
    required String? stageId,
    required String decisionCode,
    required HouseholdSharedContext sharedContext,
    required HouseholdSharedActor actor,
    required PracticeRouteArgs nextStepArgs,
    required PracticeActivitySnapshot activitySnapshot,
  }) {
    final leadPhrase = activitySnapshot.phrases.isEmpty
        ? null
        : activitySnapshot.phrases.first;
    final actorLabel = _actorRoleLabel(actor.role);
    final resultLabel = _actorResultLabel(actor.result);
    final nextStepLabel = _nextStepReasonLabel(sharedContext.nextStep?.reason);
    final stageMatch = stageId == null
        ? null
        : StageMatchCatalog.maybeForStageId(stageId);
    final coachTip = _normalize(activitySnapshot.coachTip);
    final primaryBodySegments = <String>[
      '$actorLabel刚完成一次共享练习（$resultLabel）。现在先接着${activitySnapshot.title}，$nextStepLabel。',
      if (leadPhrase != null) '可以先从“${leadPhrase.english}”开口。',
      if (coachTip != null) coachTip,
    ];
    final redactedSummary =
        'shared:$decisionCode:${_normalize(actor.role) ?? 'member'}:${nextStepArgs.activityId}';
    final suggestions = <LocalMentorSuggestion>[
      LocalMentorSuggestion(
        suggestionId: 'shared_${nextStepArgs.activityId}',
        origin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
        title: '接住家庭刚完成的练习',
        body: primaryBodySegments.join(' '),
        phraseEnglish: leadPhrase?.english,
        phraseChinese: leadPhrase?.chinese,
        stageId: stageMatch?.stageId,
        spaceId: nextStepArgs.spaceId,
        activityId: nextStepArgs.activityId,
        phraseId: leadPhrase?.phraseId,
        reasonCode: decisionCode,
        redactedContextSummary: redactedSummary,
      ),
      if (stageMatch != null)
        LocalMentorSuggestion(
          suggestionId: 'stage_${stageMatch.stageId}',
          origin: LocalMentorSuggestionOrigin.stageGuide,
          title: '保持这个阶段的节奏',
          body: '${stageMatch.summary} 这次先顺着共享下一步继续，不必临时换活动。',
          stageId: stageMatch.stageId,
          reasonCode: 'stage_reinforcement',
          redactedContextSummary: 'stage:${stageMatch.stageId}',
        ),
    ];

    return LocalMentorSuggestionResult(
      suggestions: List.unmodifiable(suggestions),
      primaryOrigin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
      contextFallbackUsed: false,
      redactedContextSummary: redactedSummary,
      sharedContextStatus: _adoptedSharedStatus(
        code: decisionCode,
        actorRole: actor.role,
        activityTitle: activitySnapshot.title,
        nextStepReason: sharedContext.nextStep?.reason,
      ),
    );
  }

  LocalMentorSuggestionResult _withSharedContextStatus(
    LocalMentorSuggestionResult result,
    MentorSharedContextStatus? status,
  ) {
    if (status == null) {
      return result;
    }
    final baseSummary = _normalize(result.redactedContextSummary);
    final redactedSummary = baseSummary == null
        ? 'shared:${status.code}'
        : '$baseSummary;shared:${status.code}';
    return LocalMentorSuggestionResult(
      suggestions: result.suggestions,
      primaryOrigin: result.primaryOrigin,
      contextFallbackUsed: result.contextFallbackUsed,
      fallbackReasonCode: result.fallbackReasonCode,
      redactedContextSummary: redactedSummary,
      sharedContextStatus: status,
    );
  }

  MentorSharedContextStatus _sharedStatusFromSnapshot(
    HouseholdLocalSnapshot snapshot,
  ) {
    final phase = _normalize(snapshot.lastPhase) ?? 'shared_context_missing';
    final visibleError = _normalize(snapshot.lastVisibleError);
    if (phase.contains('malformed')) {
      return _skippedSharedStatus(
        code: 'shared_snapshot_malformed',
        detail: '共享 household 快照格式异常，Mentor 继续使用本地建议。',
      );
    }
    if (phase.contains('offline')) {
      return _skippedSharedStatus(
        code: 'shared_snapshot_offline',
        detail: '当前离线，共享 household 快照未更新，Mentor 继续使用本地建议。',
      );
    }
    if (phase.contains('unavailable') || phase.contains('timeout')) {
      return _skippedSharedStatus(
        code: 'shared_context_unavailable',
        detail: visibleError == null
            ? '共享上下文暂不可用，Mentor 继续使用本地建议。'
            : '$visibleError Mentor 已保留本地建议。',
      );
    }
    if (phase.contains('ready') || phase.contains('accept')) {
      return _skippedSharedStatus(
        code: 'shared_context_missing',
        detail: '共享 household 快照里还没有结构化 continuity，Mentor 继续使用本地建议。',
      );
    }
    return _skippedSharedStatus(
      code: 'shared_context_missing',
      detail: visibleError == null
          ? '共享 household 快照还没准备好，Mentor 继续使用本地建议。'
          : '$visibleError Mentor 已保留本地建议。',
    );
  }

  MentorSharedContextStatus _adoptedSharedStatus({
    required String code,
    required String actorRole,
    required String activityTitle,
    required String? nextStepReason,
  }) {
    final actorLabel = _actorRoleLabel(actorRole);
    final nextStepLabel = _nextStepReasonLabel(nextStepReason);
    return MentorSharedContextStatus(
      code: code,
      adopted: true,
      headline: '已采用家庭共享连续性',
      detail:
          '$actorLabel刚完成一次共享练习，Mentor 现在按“$activityTitle”继续；$nextStepLabel。',
    );
  }

  MentorSharedContextStatus _skippedSharedStatus({
    required String code,
    required String detail,
  }) {
    return MentorSharedContextStatus(
      code: code,
      adopted: false,
      headline: '共享连续性已安全放弃',
      detail: detail,
    );
  }

  bool _isSupportedActorRole(String? role) {
    return role == 'primary_caregiver' || role == 'caregiver';
  }

  PracticeRouteArgs? _safeNextStepArgs(HouseholdSharedContext sharedContext) {
    final nextStep = sharedContext.nextStep;
    if (nextStep == null) {
      return null;
    }
    return PracticeRouteArgs.maybeCreate(
      spaceId: nextStep.spaceId,
      activityId: nextStep.activityId,
    )?.normalized();
  }

  String _actorRoleLabel(String? role) {
    switch (role?.trim()) {
      case 'primary_caregiver':
        return '主照护者';
      case 'caregiver':
        return '次照护者';
      default:
        return '家庭成员';
    }
  }

  String _actorResultLabel(String? result) {
    switch (result?.trim()) {
      case 'calm':
        return '平静回应';
      case 'engaged':
        return '愿意看着你';
      case 'imitated':
        return '开始模仿';
      case 'needs_break':
        return '需要先休息';
      default:
        return '已记录反馈';
    }
  }

  String _nextStepReasonLabel(String? reason) {
    switch (reason?.trim()) {
      case 'latest_activity':
        return '先接住刚完成的 activity';
      case 'top_activity':
        return '先接上当前最该继续的 activity';
      default:
        return '先沿着共享下一步继续';
    }
  }

  String _generateLocalEventId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'mentor_${timestamp}_$entropy';
  }

  String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _MentorContinuityContext {
  const _MentorContinuityContext({
    this.recentPractice,
    this.fallbackReasonCode,
    this.latestEventTime,
  });

  final LocalMentorRecentPracticeContext? recentPractice;
  final String? fallbackReasonCode;
  final DateTime? latestEventTime;
}

class _SharedContextResolution {
  const _SharedContextResolution({this.status, this.adoptedResult});

  final MentorSharedContextStatus? status;
  final LocalMentorSuggestionResult? adoptedResult;
}
