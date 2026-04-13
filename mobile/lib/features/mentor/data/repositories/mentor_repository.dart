import 'dart:async';
import 'dart:math';

import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

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

    final starterSpaceId = _normalize(onboardingSnapshot?.starterSpaceId);
    final starterActivityId = _normalize(onboardingSnapshot?.starterActivityId);
    final starterPhraseId = _normalize(onboardingSnapshot?.starterPhraseId);

    if (!contextFallbackUsed &&
        (starterSpaceId == null ||
            starterActivityId == null ||
            starterPhraseId == null)) {
      contextFallbackUsed = true;
      fallbackReasonCode = 'starter_seed_missing';
    }

    PracticeRestoreSnapshot? restoredPractice;
    if (!contextFallbackUsed) {
      try {
        restoredPractice = await _practiceRepository.restorePracticeState(
          spaceId: starterSpaceId!,
          activityId: starterActivityId!,
        );
      } on TimeoutException {
        contextFallbackUsed = true;
        fallbackReasonCode = 'practice_restore_timeout';
      } on FormatException {
        contextFallbackUsed = true;
        fallbackReasonCode = 'practice_restore_malformed';
      } catch (_) {
        contextFallbackUsed = true;
        fallbackReasonCode = 'practice_restore_failed';
      }
    }

    final suggestionContext = LocalMentorSuggestionContext(
      stageId: _normalize(onboardingSnapshot?.currentStage),
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
      starterPhraseId: starterPhraseId,
      activityTitle: restoredPractice?.activitySnapshot.title,
      activitySummary: restoredPractice?.activitySnapshot.summary,
      coachTip: restoredPractice?.activitySnapshot.coachTip,
      sceneTag: restoredPractice?.activitySnapshot.sceneTag,
      phrases:
          restoredPractice?.activitySnapshot.phrases
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
      recentPractice: _mapRecentPractice(restoredPractice),
      contextFallbackUsed: contextFallbackUsed,
      fallbackReasonCode: fallbackReasonCode,
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

  LocalMentorRecentPracticeContext? _mapRecentPractice(
    PracticeRestoreSnapshot? restoredPractice,
  ) {
    final recent = restoredPractice?.homeSummary.recentResult;
    if (recent == null) {
      return null;
    }
    return LocalMentorRecentPracticeContext(
      activityId: recent.activityId,
      activityTitle: recent.activityTitle,
      phraseId: recent.phraseId,
      phraseEnglish: recent.phraseEnglish,
      reactionType: recent.reactionType,
      totalEvents: recent.totalEvents,
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
