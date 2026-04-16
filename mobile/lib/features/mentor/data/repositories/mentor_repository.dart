import 'dart:async';
import 'dart:math';

import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';

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
    Random? random,
  }) : _localDataSource = localDataSource,
       _practiceRepository = practiceRepository,
       _onboardingSnapshotStore = onboardingSnapshotStore,
       _suggestionService =
           suggestionService ?? const LocalMentorSuggestionService(),
       _random = random ?? Random();

  final MentorLocalDataSource _localDataSource;
  final PracticeRepository _practiceRepository;
  final OnboardingSnapshotStore _onboardingSnapshotStore;
  final LocalMentorSuggestionService _suggestionService;
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

    return _suggestionService.derive(suggestionContext);
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
    if (recommendationReason != PracticeContinuityReason.recentActivity) {
      return _MentorContinuityContext(
        fallbackReasonCode: recommendationReason.wireValue,
      );
    }

    final recentActivity =
        snapshot.recentActivity ?? snapshot.recommendedActivity;
    final recentResult = recentActivity.recentResult;
    if (recentResult == null) {
      return const _MentorContinuityContext(
        fallbackReasonCode: 'recent_context_missing',
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
      return const _MentorContinuityContext(
        fallbackReasonCode: 'recent_context_unmapped',
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
    );
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
  });

  final LocalMentorRecentPracticeContext? recentPractice;
  final String? fallbackReasonCode;
}
