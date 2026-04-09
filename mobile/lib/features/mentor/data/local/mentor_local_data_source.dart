import 'package:isar/isar.dart';
import 'package:mobile/features/mentor/data/local/mentor_fact_event_entity.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';

typedef MentorIsarOpener =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      String name,
    });

class MentorPersistenceException implements Exception {
  MentorPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'MentorPersistenceException: $message'
        : 'MentorPersistenceException: $message ($cause)';
  }
}

class MentorLocalDataSource {
  MentorLocalDataSource({required Isar isar}) : _isar = isar;

  final Isar _isar;

  Isar get isar => _isar;

  static Future<MentorLocalDataSource> open({
    required String directory,
    String name = 'mentor_local',
    MentorIsarOpener? isarOpener,
  }) async {
    final opener = isarOpener ?? Isar.open;
    try {
      final isar = await opener(
        [MentorFactEventEntitySchema],
        directory: directory,
        name: name,
      );
      return MentorLocalDataSource(isar: isar);
    } catch (error) {
      throw MentorPersistenceException('打开 mentor 本地事实库失败。', error);
    }
  }

  static MentorFactEvent payloadFromEntity(MentorFactEventEntity entity) {
    return MentorFactEvent.fromWire(
      eventKey: entity.eventKey,
      localEventId: entity.localEventId,
      installationId: entity.installationId,
      eventType: entity.eventType,
      phase: entity.phase,
      createdAt: entity.createdAt,
      correlationId: entity.correlationId,
      redactedSummary: entity.redactedSummary,
      visibleStatus: entity.visibleStatus,
      visibleDetail: entity.visibleDetail,
      retryable: entity.retryable,
      contextFallbackUsed: entity.contextFallbackUsed,
    );
  }

  Future<void> appendMentorFactEvent(MentorFactEvent payload) async {
    try {
      final collection = _isar.collection<MentorFactEventEntity>();
      await _isar.writeTxn(() async {
        final existing = await collection.getByEventKey(payload.eventKey);
        if (existing != null) {
          throw const FormatException(
            'eventKey 已存在，append-only mentor fact 不可覆盖。',
          );
        }
        await collection.putByEventKey(
          MentorFactEventEntity.fromPayload(payload),
        );
      });
    } on FormatException {
      rethrow;
    } catch (error) {
      throw MentorPersistenceException('追加 mentor fact 失败。', error);
    }
  }

  Future<int> countMentorFacts({MentorFactType? eventType}) async {
    try {
      return _isar.txn(() async {
        final collection = _isar.collection<MentorFactEventEntity>();
        if (eventType == null) {
          return collection.where().count();
        }
        return collection.where().eventTypeEqualTo(eventType.wireValue).count();
      });
    } catch (error) {
      throw MentorPersistenceException('统计 mentor fact 失败。', error);
    }
  }

  Future<List<MentorFactEvent>> listMentorFactEvents({
    MentorFactType? eventType,
    int? limit,
  }) async {
    final entities = await listRawEntities(eventType: eventType, limit: limit);
    return entities.map(payloadFromEntity).toList(growable: false);
  }

  Future<List<MentorFactEventEntity>> listRawEntities({
    MentorFactType? eventType,
    int? limit,
  }) async {
    try {
      final entities = await _isar.txn(() async {
        final collection = _isar.collection<MentorFactEventEntity>();
        if (eventType == null) {
          return collection.where().findAll();
        }
        return collection
            .where()
            .eventTypeEqualTo(eventType.wireValue)
            .findAll();
      });
      entities.sort(_compareEntities);
      if (limit == null || limit >= entities.length) {
        return entities;
      }
      return entities.take(limit).toList(growable: false);
    } catch (error) {
      throw MentorPersistenceException('读取 mentor fact 失败。', error);
    }
  }

  Future<MentorFactEvent?> latestMentorFact({MentorFactType? eventType}) async {
    try {
      final entity = await _latestRawEntity(eventType: eventType);
      if (entity == null) {
        return null;
      }
      return payloadFromEntity(entity);
    } catch (error) {
      throw MentorPersistenceException('读取最近 mentor fact 失败。', error);
    }
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    await _isar.close(deleteFromDisk: deleteFromDisk);
  }

  Future<MentorFactEventEntity?> _latestRawEntity({MentorFactType? eventType}) {
    return _isar.txn(() async {
      final collection = _isar.collection<MentorFactEventEntity>();
      if (eventType == null) {
        return collection.where().sortByCreatedAtDesc().findFirst();
      }
      return collection
          .where()
          .eventTypeEqualTo(eventType.wireValue)
          .sortByCreatedAtDesc()
          .findFirst();
    });
  }

  int _compareEntities(MentorFactEventEntity a, MentorFactEventEntity b) {
    final byCreatedAt = a.createdAt.compareTo(b.createdAt);
    if (byCreatedAt != 0) {
      return byCreatedAt;
    }
    return a.eventKey.compareTo(b.eventKey);
  }
}
