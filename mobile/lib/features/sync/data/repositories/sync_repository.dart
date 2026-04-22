import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

typedef SyncInstallationIdReader = Future<String?> Function();

class SyncQueueSummary {
  const SyncQueueSummary({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.lastPendingAt,
    this.lastSyncedAt,
    this.lastFailedAt,
    this.lastSyncPhase,
    this.lastSyncError,
    this.lastSyncAt,
  });

  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final DateTime? lastPendingAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastFailedAt;
  final String? lastSyncPhase;
  final String? lastSyncError;
  final DateTime? lastSyncAt;
}

SyncQueueSummary summarizeSyncQueueEvents(
  List<InteractionEventPayload> events,
) {
  DateTime? lastPendingAt;
  DateTime? lastSyncedAt;
  DateTime? lastFailedAt;
  var pendingCount = 0;
  var syncedCount = 0;
  var failedCount = 0;
  InteractionEventPayload? lastSyncedMetadataSource;

  for (final event in events) {
    switch (event.syncState) {
      case InteractionSyncState.pending:
        pendingCount += 1;
        lastPendingAt = event.clientTimestamp;
        break;
      case InteractionSyncState.synced:
        syncedCount += 1;
        lastSyncedAt = event.lastSyncAt ?? event.clientTimestamp;
        break;
      case InteractionSyncState.failed:
        failedCount += 1;
        lastFailedAt = event.lastSyncAt ?? event.clientTimestamp;
        break;
    }

    final syncTimestamp = event.lastSyncAt;
    if (syncTimestamp == null) {
      continue;
    }
    final currentLastTimestamp = lastSyncedMetadataSource?.lastSyncAt;
    if (currentLastTimestamp == null ||
        syncTimestamp.isAfter(currentLastTimestamp)) {
      lastSyncedMetadataSource = event;
    }
  }

  return SyncQueueSummary(
    pendingCount: pendingCount,
    syncedCount: syncedCount,
    failedCount: failedCount,
    lastPendingAt: lastPendingAt,
    lastSyncedAt: lastSyncedAt,
    lastFailedAt: lastFailedAt,
    lastSyncPhase: lastSyncedMetadataSource?.lastSyncPhase,
    lastSyncError: lastSyncedMetadataSource?.lastSyncError,
    lastSyncAt: lastSyncedMetadataSource?.lastSyncAt,
  );
}

class SyncQueueInspection {
  const SyncQueueInspection({
    required this.installationId,
    required this.summary,
    required this.pendingUploads,
  });

  final String? installationId;
  final SyncQueueSummary summary;
  final List<InteractionEventUploadRecord> pendingUploads;
}

class SyncRepository {
  SyncRepository({
    required PracticeLocalDataSource localDataSource,
    required SyncInstallationIdReader installationIdReader,
  }) : _localDataSource = localDataSource,
       _installationIdReader = installationIdReader;

  final PracticeLocalDataSource _localDataSource;
  final SyncInstallationIdReader _installationIdReader;

  Future<String?> readInstallationId() {
    return _installationIdReader();
  }

  Future<List<InteractionEventUploadRecord>> listPendingUploads({
    String? activityId,
    int? limit,
  }) async {
    final events = await _localDataSource.listPendingEvents(
      activityId: activityId,
      limit: limit,
    );
    return events.map((event) => event.uploadRecord).toList(growable: false);
  }

  Future<SyncQueueSummary> inspectSyncState({String? activityId}) async {
    final events = await _localDataSource.listInteractionEvents(
      activityId: activityId,
    );
    return summarizeSyncQueueEvents(events);
  }

  Future<SyncQueueInspection> inspectQueue({
    String? activityId,
    int? pendingLimit,
  }) async {
    final installationId = await _installationIdReader();
    final summary = await inspectSyncState(activityId: activityId);
    final pendingUploads = await listPendingUploads(
      activityId: activityId,
      limit: pendingLimit,
    );
    return SyncQueueInspection(
      installationId: installationId,
      summary: summary,
      pendingUploads: pendingUploads,
    );
  }

  Future<void> markBatchSynced(
    Iterable<String> eventKeys, {
    String phase = 'batch_ack_applied',
    DateTime? syncedAt,
  }) {
    return _localDataSource.markEventsSynced(
      eventKeys,
      phase: phase,
      syncedAt: syncedAt,
    );
  }

  Future<void> markBatchFailed(
    Iterable<String> eventKeys, {
    required String phase,
    required String errorMessage,
    DateTime? failedAt,
    bool keepPending = false,
  }) {
    return _localDataSource.markEventsFailed(
      eventKeys,
      phase: phase,
      errorMessage: errorMessage,
      failedAt: failedAt,
      keepPending: keepPending,
    );
  }

  Future<void> importBootstrapEvents(Iterable<InteractionEventPayload> events) {
    return _localDataSource.importServerEvents(events);
  }
}
