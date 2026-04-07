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

  Future<void> appendInteractionEvent(InteractionEventPayload payload) async {
    final existingEvents = await listRawEntities();
    final duplicateFound = existingEvents.any(
      (entity) => entity.localEventId == payload.localEventId,
    );
    if (duplicateFound) {
      throw const FormatException('localEventId 已存在，append-only 事件不可覆盖。');
    }

    final collection = _isar.collection<InteractionEventEntity>();
    final entity = InteractionEventEntity.fromPayload(payload);
    await _isar.writeTxn(() async {
      await collection.put(entity);
    });
  }

  Future<List<InteractionEventPayload>> listInteractionEvents({
    String? activityId,
  }) async {
    final entities = await listRawEntities(activityId: activityId);
    return entities.map(_payloadFromEntity).toList(growable: false);
  }

  Future<List<InteractionEventEntity>> listRawEntities({
    String? activityId,
  }) async {
    final entities = await _isar.txn(() async {
      return _isar.collection<InteractionEventEntity>().where().findAll();
    });

    final filtered = activityId == null
        ? entities
        : entities
              .where((entity) => entity.activityId == activityId)
              .toList(growable: false);

    filtered.sort((a, b) {
      final byTimestamp = a.clientTimestamp.compareTo(b.clientTimestamp);
      if (byTimestamp != 0) {
        return byTimestamp;
      }
      return a.localEventId.compareTo(b.localEventId);
    });
    return filtered;
  }

  Future<InteractionEventPayload?> latestInteractionEvent({
    String? activityId,
  }) async {
    final events = await listInteractionEvents(activityId: activityId);
    if (events.isEmpty) {
      return null;
    }
    return events.last;
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    await _isar.close(deleteFromDisk: deleteFromDisk);
  }

  InteractionEventPayload _payloadFromEntity(InteractionEventEntity entity) {
    return InteractionEventPayload.fromWire(
      localEventId: entity.localEventId,
      installationId: entity.installationId,
      spaceId: entity.spaceId,
      activityId: entity.activityId,
      phraseId: entity.phraseId,
      reactionType: entity.reactionType,
      clientTimestamp: entity.clientTimestamp,
      syncState: entity.syncState,
    );
  }
}
