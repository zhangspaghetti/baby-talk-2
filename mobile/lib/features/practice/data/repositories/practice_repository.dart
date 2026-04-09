import 'dart:math';

import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

class PracticeActivitySnapshot {
  const PracticeActivitySnapshot({
    required this.spaceId,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
  });

  final String spaceId;
  final String activityId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<PracticePhrase> phrases;
}

class PracticeRecentResultSummary {
  const PracticeRecentResultSummary({
    required this.activityId,
    required this.activityTitle,
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.eventTime,
    required this.totalEvents,
  });

  final String activityId;
  final String activityTitle;
  final String phraseId;
  final String phraseEnglish;
  final BabyReactionType reactionType;
  final DateTime eventTime;
  final int totalEvents;
}

class PracticeHomeSummary {
  const PracticeHomeSummary({
    required this.spaceId,
    required this.activityId,
    required this.activityTitle,
    required this.totalEvents,
    required this.lastEventTime,
    required this.recentResult,
  });

  final String spaceId;
  final String activityId;
  final String activityTitle;
  final int totalEvents;
  final DateTime? lastEventTime;
  final PracticeRecentResultSummary? recentResult;

  bool get isEmpty => totalEvents == 0;
}

class PracticeSyncSummary {
  const PracticeSyncSummary({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.lastPendingAt,
    this.lastSyncedAt,
    this.lastFailedAt,
  });

  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final DateTime? lastPendingAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastFailedAt;

  DateTime? get lastEventAt {
    final candidates = [
      lastPendingAt,
      lastSyncedAt,
      lastFailedAt,
    ].whereType<DateTime>().toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort();
    return candidates.last;
  }
}

class PracticeResumeInfo {
  const PracticeResumeInfo({
    required this.activityId,
    required this.totalPhrases,
    required this.completedPhraseIds,
    required this.nextPhraseId,
    required this.lastEventTime,
  });

  final String activityId;
  final int totalPhrases;
  final List<String> completedPhraseIds;
  final String? nextPhraseId;
  final DateTime? lastEventTime;

  int get completedCount => completedPhraseIds.length;
  bool get isEmpty => completedPhraseIds.isEmpty;
  bool get isComplete => completedCount >= totalPhrases && totalPhrases > 0;
}

class PracticeEventInspectionIssue {
  const PracticeEventInspectionIssue({
    required this.message,
    this.localEventId,
    this.clientTimestamp,
  });

  final String message;
  final String? localEventId;
  final DateTime? clientTimestamp;
}

class PracticeEventInspection {
  const PracticeEventInspection({
    required this.installationId,
    required this.storedEventCount,
    required this.validEvents,
    required this.skippedEventCount,
    this.lastIssue,
    this.scanErrorMessage,
  });

  final String? installationId;
  final int storedEventCount;
  final List<InteractionEventPayload> validEvents;
  final int skippedEventCount;
  final PracticeEventInspectionIssue? lastIssue;
  final String? scanErrorMessage;

  int get validEventCount => validEvents.length;
  bool get hasRecoverableIssue =>
      skippedEventCount > 0 || scanErrorMessage != null;
}

class PracticeRestoreSnapshot {
  const PracticeRestoreSnapshot({
    required this.installationId,
    required this.activitySnapshot,
    required this.homeSummary,
    required this.resumeInfo,
    required this.inspection,
    required this.restoreMessage,
    required this.hasRecoverableIssue,
  });

  final String? installationId;
  final PracticeActivitySnapshot activitySnapshot;
  final PracticeHomeSummary homeSummary;
  final PracticeResumeInfo resumeInfo;
  final PracticeEventInspection inspection;
  final String restoreMessage;
  final bool hasRecoverableIssue;
}

class PracticeRepository {
  PracticeRepository({
    required AssetPhraseService assetPhraseService,
    required PracticeLocalDataSource localDataSource,
    required InstallationIdService installationIdService,
    Random? random,
  }) : _assetPhraseService = assetPhraseService,
       _localDataSource = localDataSource,
       _installationIdService = installationIdService,
       _random = random ?? Random();

  final AssetPhraseService _assetPhraseService;
  final PracticeLocalDataSource _localDataSource;
  final InstallationIdService _installationIdService;
  final Random _random;
  bool _isClosed = false;

  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await _assetPhraseService.loadActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phrases = await _assetPhraseService.loadPracticePhrases(
      spaceId: spaceId,
      activityId: activityId,
    );
    return PracticeActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
      title: activity.title,
      summary: activity.summary,
      sceneTag: activity.sceneTag,
      coachTip: activity.coachTip,
      phrases: phrases,
    );
  }

  Future<String> ensureInstallationId() {
    return _installationIdService.getOrCreate();
  }

  Future<String?> readExistingInstallationId() {
    return _installationIdService.readExisting();
  }

  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phraseExists = snapshot.phrases.any(
      (phrase) => phrase.phraseId == phraseId,
    );
    if (!phraseExists) {
      throw FormatException('未知 phraseId: $spaceId/$activityId/$phraseId');
    }

    final payload = InteractionEventPayload(
      localEventId: localEventId ?? _generateLocalEventId(),
      installationId: await _installationIdService.getOrCreate(),
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.now().toUtc(),
    );
    await _localDataSource.appendInteractionEvent(payload);
    return payload;
  }

  Future<PracticeRestoreSnapshot> restorePracticeState({
    required String spaceId,
    required String activityId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );

    final installationId = await _safeEnsureInstallationId();
    final inspection = await _safeInspectEventLog(
      activityId: activityId,
      installationId: installationId,
    );

    final derivableEvents = _filterDerivableEvents(
      snapshot: snapshot,
      events: inspection.validEvents,
    );
    final skippedUnknownPhraseCount =
        inspection.validEventCount - derivableEvents.length;

    final homeSummary = _buildHomeSummary(
      snapshot: snapshot,
      events: derivableEvents,
    );
    final resumeInfo = _buildResumeInfo(
      snapshot: snapshot,
      events: derivableEvents,
    );

    final hasRecoverableIssue =
        inspection.hasRecoverableIssue || skippedUnknownPhraseCount > 0;

    return PracticeRestoreSnapshot(
      installationId: installationId,
      activitySnapshot: snapshot,
      homeSummary: homeSummary,
      resumeInfo: resumeInfo,
      inspection: inspection,
      restoreMessage: _buildRestoreMessage(
        homeSummary: homeSummary,
        inspection: inspection,
        skippedUnknownPhraseCount: skippedUnknownPhraseCount,
      ),
      hasRecoverableIssue: hasRecoverableIssue,
    );
  }

  Future<PracticeHomeSummary> getHomeSummary({
    required String spaceId,
    required String activityId,
  }) async {
    final restored = await restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    return restored.homeSummary;
  }

  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final restored = await restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    return restored.resumeInfo;
  }

  Future<PracticeEventInspection> inspectEventLog({
    String? activityId,
    String? installationIdOverride,
  }) async {
    final rawEntities = await _localDataSource.listRawEntities(
      activityId: activityId,
    );

    final validEvents = <InteractionEventPayload>[];
    var skippedEventCount = 0;
    PracticeEventInspectionIssue? lastIssue;

    for (final entity in rawEntities) {
      try {
        validEvents.add(PracticeLocalDataSource.payloadFromEntity(entity));
      } catch (error) {
        skippedEventCount += 1;
        lastIssue = PracticeEventInspectionIssue(
          localEventId: entity.localEventId,
          clientTimestamp: entity.clientTimestamp,
          message: '$error',
        );
      }
    }

    return PracticeEventInspection(
      installationId:
          installationIdOverride ?? await _installationIdService.readExisting(),
      storedEventCount: rawEntities.length,
      validEvents: List.unmodifiable(validEvents),
      skippedEventCount: skippedEventCount,
      lastIssue: lastIssue,
    );
  }

  Future<PracticeSyncSummary> getSyncSummary({String? activityId}) async {
    final events = await listEventHistory(activityId: activityId);
    DateTime? lastPendingAt;
    DateTime? lastSyncedAt;
    DateTime? lastFailedAt;
    var pendingCount = 0;
    var syncedCount = 0;
    var failedCount = 0;

    for (final event in events) {
      switch (event.syncState) {
        case InteractionSyncState.pending:
          pendingCount += 1;
          lastPendingAt = event.clientTimestamp;
          break;
        case InteractionSyncState.synced:
          syncedCount += 1;
          lastSyncedAt = event.clientTimestamp;
          break;
        case InteractionSyncState.failed:
          failedCount += 1;
          lastFailedAt = event.clientTimestamp;
          break;
      }
    }

    return PracticeSyncSummary(
      pendingCount: pendingCount,
      syncedCount: syncedCount,
      failedCount: failedCount,
      lastPendingAt: lastPendingAt,
      lastSyncedAt: lastSyncedAt,
      lastFailedAt: lastFailedAt,
    );
  }

  Future<List<InteractionEventPayload>> listEventHistory({String? activityId}) {
    return _localDataSource.listInteractionEvents(activityId: activityId);
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    await _localDataSource.close(deleteFromDisk: deleteFromDisk);
  }

  Future<String?> _safeEnsureInstallationId() async {
    try {
      return await _installationIdService.getOrCreate();
    } catch (_) {
      return await _installationIdService.readExisting();
    }
  }

  Future<PracticeEventInspection> _safeInspectEventLog({
    required String activityId,
    required String? installationId,
  }) async {
    try {
      return await inspectEventLog(
        activityId: activityId,
        installationIdOverride: installationId,
      );
    } catch (error) {
      return PracticeEventInspection(
        installationId: installationId,
        storedEventCount: 0,
        validEvents: const <InteractionEventPayload>[],
        skippedEventCount: 0,
        scanErrorMessage: '本地事件读取失败：$error',
      );
    }
  }

  List<InteractionEventPayload> _filterDerivableEvents({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    final knownPhraseIds = snapshot.phrases
        .map((phrase) => phrase.phraseId)
        .toSet();
    return events
        .where((event) => knownPhraseIds.contains(event.phraseId))
        .toList(growable: false);
  }

  PracticeHomeSummary _buildHomeSummary({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    if (events.isEmpty) {
      return PracticeHomeSummary(
        spaceId: snapshot.spaceId,
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        totalEvents: 0,
        lastEventTime: null,
        recentResult: null,
      );
    }

    final latest = events.last;
    final phraseById = {
      for (final phrase in snapshot.phrases) phrase.phraseId: phrase,
    };
    final latestPhrase = phraseById[latest.phraseId];
    if (latestPhrase == null) {
      return PracticeHomeSummary(
        spaceId: snapshot.spaceId,
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        totalEvents: 0,
        lastEventTime: null,
        recentResult: null,
      );
    }

    return PracticeHomeSummary(
      spaceId: snapshot.spaceId,
      activityId: snapshot.activityId,
      activityTitle: snapshot.title,
      totalEvents: events.length,
      lastEventTime: latest.clientTimestamp,
      recentResult: PracticeRecentResultSummary(
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        phraseId: latest.phraseId,
        phraseEnglish: latestPhrase.english,
        reactionType: latest.reactionType,
        eventTime: latest.clientTimestamp,
        totalEvents: events.length,
      ),
    );
  }

  PracticeResumeInfo _buildResumeInfo({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    final completedPhraseIds = <String>[];
    for (final event in events) {
      if (!completedPhraseIds.contains(event.phraseId)) {
        completedPhraseIds.add(event.phraseId);
      }
    }

    String? nextPhraseId;
    for (final phrase in snapshot.phrases) {
      if (!completedPhraseIds.contains(phrase.phraseId)) {
        nextPhraseId = phrase.phraseId;
        break;
      }
    }
    nextPhraseId ??= snapshot.phrases.isEmpty
        ? null
        : snapshot.phrases.last.phraseId;

    return PracticeResumeInfo(
      activityId: snapshot.activityId,
      totalPhrases: snapshot.phrases.length,
      completedPhraseIds: List.unmodifiable(completedPhraseIds),
      nextPhraseId: nextPhraseId,
      lastEventTime: events.isEmpty ? null : events.last.clientTimestamp,
    );
  }

  String _buildRestoreMessage({
    required PracticeHomeSummary homeSummary,
    required PracticeEventInspection inspection,
    required int skippedUnknownPhraseCount,
  }) {
    if (inspection.scanErrorMessage != null) {
      return '${inspection.scanErrorMessage}；已退回安全空态，可直接重新开始 guest 练习。';
    }

    if (inspection.skippedEventCount > 0) {
      final issue = inspection.lastIssue;
      final localEventId = issue?.localEventId;
      final reason = issue?.message;
      final detail = [
        if (localEventId != null && localEventId.isNotEmpty)
          '最近失败 localEventId=$localEventId',
        if (reason != null && reason.isNotEmpty) reason,
      ].join('，');
      return detail.isEmpty
          ? '恢复时跳过 ${inspection.skippedEventCount} 条损坏记录。'
          : '恢复时跳过 ${inspection.skippedEventCount} 条损坏记录：$detail。';
    }

    if (skippedUnknownPhraseCount > 0) {
      return '恢复时跳过 $skippedUnknownPhraseCount 条未知短语记录；已保留其余本地结果。';
    }

    if (homeSummary.isEmpty) {
      return '未找到本地记录，可以直接开始 guest 练习。';
    }

    return '已从本地恢复最近一次练习结果，共 ${homeSummary.totalEvents} 条记录。';
  }

  String _generateLocalEventId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'evt_${timestamp}_$entropy';
  }
}
