import 'package:isar/isar.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

typedef PracticeIsarOpener =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      String name,
    });

class PracticePersistenceException implements Exception {
  PracticePersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'PracticePersistenceException: $message'
        : 'PracticePersistenceException: $message ($cause)';
  }
}

class PracticeLocalDataSource {
  PracticeLocalDataSource({required Isar isar}) : _isar = isar;

  final Isar _isar;

  Isar get isar => _isar;

  static Future<PracticeLocalDataSource> open({
    required String directory,
    String name = 'practice_local',
    PracticeIsarOpener? isarOpener,
  }) async {
    final opener = isarOpener ?? Isar.open;
    try {
      final isar = await opener(
        [InteractionEventEntitySchema],
        directory: directory,
        name: name,
      );
      return PracticeLocalDataSource(isar: isar);
    } catch (error) {
      throw PracticePersistenceException('打开本地事件库失败。', error);
    }
  }

  static InteractionEventPayload payloadFromEntity(
    InteractionEventEntity entity,
  ) {
    return InteractionEventPayload.fromWire(
      eventKey: entity.eventKey,
      localEventId: entity.localEventId,
      installationId: entity.installationId,
      spaceId: entity.spaceId,
      activityId: entity.activityId,
      phraseId: entity.phraseId,
      reactionType: entity.reactionType,
      clientTimestamp: entity.clientTimestamp,
      syncState: entity.syncState,
      lastSyncPhase: entity.lastSyncPhase,
      lastSyncError: entity.lastSyncError,
      lastSyncAt: entity.lastSyncAt,
    );
  }

  Future<void> appendInteractionEvent(InteractionEventPayload payload) async {
    final collection = _isar.collection<InteractionEventEntity>();
    await _isar.writeTxn(() async {
      final existing = await collection.getByEventKey(payload.eventKey);
      if (existing != null) {
        throw const FormatException('eventKey 已存在，append-only 事件不可覆盖。');
      }
      await collection.putByEventKey(InteractionEventEntity.fromPayload(payload));
    });
  }

  Future<int> countInteractionEvents({
    String? spaceId,
    String? activityId,
  }) async {
    final entities = await listRawEntities(spaceId: spaceId, activityId: activityId);
    return entities.length;
  }

  Future<List<InteractionEventPayload>> listInteractionEvents({
    String? spaceId,
    String? activityId,
  }) async {
    final entities = await listRawEntities(
      spaceId: spaceId,
      activityId: activityId,
    );
    return entities.map(payloadFromEntity).toList(growable: false);
  }

  Future<List<InteractionEventPayload>> listPendingEvents({
    String? spaceId,
    String? activityId,
    int? limit,
  }) async {
    final entities = await listPendingRawEntities(
      spaceId: spaceId,
      activityId: activityId,
      limit: limit,
    );
    return entities.map(payloadFromEntity).toList(growable: false);
  }

  Future<List<InteractionEventEntity>> listRawEntities({
    String? spaceId,
    String? activityId,
  }) async {
    final entities = await _isar.txn(() async {
      final collection = _isar.collection<InteractionEventEntity>();
      if (spaceId == null && activityId == null) {
        return collection.where().findAll();
      }
      if (spaceId != null && activityId != null) {
        return collection
            .filter()
            .spaceIdEqualTo(spaceId)
            .activityIdEqualTo(activityId)
            .findAll();
      }
      if (spaceId != null) {
        return collection.filter().spaceIdEqualTo(spaceId).findAll();
      }
      return collection.filter().activityIdEqualTo(activityId!).findAll();
    });

    entities.sort(_compareEntities);
    return entities;
  }

  Future<List<InteractionEventEntity>> listPendingRawEntities({
    String? spaceId,
    String? activityId,
    int? limit,
  }) async {
    final entities = await _isar.txn(() async {
      final collection = _isar.collection<InteractionEventEntity>();
      if (spaceId == null && activityId == null) {
        return collection
            .where()
            .syncStateEqualTo(InteractionSyncState.pending.wireValue)
            .findAll();
      }
      if (spaceId != null && activityId != null) {
        return collection
            .filter()
            .spaceIdEqualTo(spaceId)
            .activityIdEqualTo(activityId)
            .syncStateEqualTo(InteractionSyncState.pending.wireValue)
            .findAll();
      }
      if (spaceId != null) {
        return collection
            .filter()
            .spaceIdEqualTo(spaceId)
            .syncStateEqualTo(InteractionSyncState.pending.wireValue)
            .findAll();
      }
      return collection
          .filter()
          .activityIdEqualTo(activityId!)
          .syncStateEqualTo(InteractionSyncState.pending.wireValue)
          .findAll();
    });

    entities.sort(_compareEntities);
    if (limit == null || limit >= entities.length) {
      return entities;
    }
    return entities.take(limit).toList(growable: false);
  }

  Future<InteractionEventPayload?> latestInteractionEvent({
    String? activityId,
  }) async {
    final entity = await latestRawEntity(activityId: activityId);
    if (entity == null) {
      return null;
    }
    return payloadFromEntity(entity);
  }

  Future<InteractionEventEntity?> latestRawEntity({String? activityId}) async {
    return _isar.txn(() async {
      final collection = _isar.collection<InteractionEventEntity>();
      if (activityId == null) {
        return collection.where().sortByClientTimestampDesc().findFirst();
      }
      return collection
          .where()
          .activityIdEqualTo(activityId)
          .sortByClientTimestampDesc()
          .findFirst();
    });
  }

  Future<void> markEventsSynced(
    Iterable<String> eventKeys, {
    String phase = 'batch_ack_applied',
    DateTime? syncedAt,
  }) async {
    final normalizedKeys = _normalizeEventKeys(eventKeys);
    if (normalizedKeys.isEmpty) {
      return;
    }

    final timestamp = (syncedAt ?? DateTime.now()).toUtc();
    final collection = _isar.collection<InteractionEventEntity>();
    await _isar.writeTxn(() async {
      final entities = await _loadEntitiesForMutation(collection, normalizedKeys);
      for (final entity in entities) {
        entity.syncState = InteractionSyncState.synced.wireValue;
        entity.lastSyncPhase = phase;
        entity.lastSyncError = null;
        entity.lastSyncAt = timestamp;
        await collection.putByEventKey(entity);
      }
    });
  }

  Future<void> markEventsFailed(
    Iterable<String> eventKeys, {
    required String phase,
    required String errorMessage,
    DateTime? failedAt,
    bool keepPending = false,
  }) async {
    if (phase.trim().isEmpty) {
      throw const FormatException('phase 不能为空。');
    }
    if (errorMessage.trim().isEmpty) {
      throw const FormatException('errorMessage 不能为空。');
    }

    final normalizedKeys = _normalizeEventKeys(eventKeys);
    if (normalizedKeys.isEmpty) {
      return;
    }

    final timestamp = (failedAt ?? DateTime.now()).toUtc();
    final targetState = keepPending
        ? InteractionSyncState.pending.wireValue
        : InteractionSyncState.failed.wireValue;
    final collection = _isar.collection<InteractionEventEntity>();
    await _isar.writeTxn(() async {
      final entities = await _loadEntitiesForMutation(collection, normalizedKeys);
      for (final entity in entities) {
        entity.syncState = targetState;
        entity.lastSyncPhase = phase;
        entity.lastSyncError = errorMessage;
        entity.lastSyncAt = timestamp;
        await collection.putByEventKey(entity);
      }
    });
  }

  Future<void> importServerEvents(
    Iterable<InteractionEventPayload> events,
  ) async {
    final collection = _isar.collection<InteractionEventEntity>();
    final incoming = events.toList(growable: false);
    await _isar.writeTxn(() async {
      final seenKeys = <String>{};
      for (final payload in incoming) {
        if (!seenKeys.add(payload.eventKey)) {
          throw FormatException('bootstrap 导入收到重复 eventKey: ${payload.eventKey}');
        }

        final existing = await collection.getByEventKey(payload.eventKey);
        if (existing == null) {
          await collection.putByEventKey(InteractionEventEntity.fromPayload(payload));
          continue;
        }

        final existingPayload = payloadFromEntity(existing);
        final sameFacts = _mapsEqual(
          existingPayload.toFactMap(),
          payload.toFactMap(),
        );
        if (!sameFacts) {
          throw FormatException(
            'bootstrap 导入收到冲突 eventKey: ${payload.eventKey}',
          );
        }
      }
    });
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    await _isar.close(deleteFromDisk: deleteFromDisk);
  }

  List<String> _normalizeEventKeys(Iterable<String> eventKeys) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final rawKey in eventKeys) {
      final key = rawKey.trim();
      if (key.isEmpty) {
        throw const FormatException('eventKey 不能为空。');
      }
      if (!seen.add(key)) {
        throw FormatException('eventKeys 中包含重复值：$key');
      }
      normalized.add(key);
    }
    return normalized;
  }

  Future<List<InteractionEventEntity>> _loadEntitiesForMutation(
    IsarCollection<InteractionEventEntity> collection,
    List<String> eventKeys,
  ) async {
    final entities = <InteractionEventEntity>[];
    final missingKeys = <String>[];
    for (final eventKey in eventKeys) {
      final entity = await collection.getByEventKey(eventKey);
      if (entity == null) {
        missingKeys.add(eventKey);
        continue;
      }
      entities.add(entity);
    }
    if (missingKeys.isNotEmpty) {
      throw FormatException('同步响应包含未知 eventKey: ${missingKeys.join(', ')}');
    }
    return entities;
  }

  int _compareEntities(InteractionEventEntity a, InteractionEventEntity b) {
    final byTimestamp = a.clientTimestamp.compareTo(b.clientTimestamp);
    if (byTimestamp != 0) {
      return byTimestamp;
    }
    return a.eventKey.compareTo(b.eventKey);
  }

  bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) {
        return false;
      }
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
