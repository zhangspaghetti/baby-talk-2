// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../../features/practice/data/local/interaction_event_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetInteractionEventEntityCollection on Isar {
  IsarCollection<InteractionEventEntity> get interactionEventEntitys =>
      this.collection();
}

const InteractionEventEntitySchema = CollectionSchema(
  name: r'InteractionEventEntity',
  id: 2959896369879111350,
  properties: {
    r'activityId': PropertySchema(
      id: 0,
      name: r'activityId',
      type: IsarType.string,
    ),
    r'clientTimestamp': PropertySchema(
      id: 1,
      name: r'clientTimestamp',
      type: IsarType.dateTime,
    ),
    r'eventKey': PropertySchema(
      id: 2,
      name: r'eventKey',
      type: IsarType.string,
    ),
    r'installationId': PropertySchema(
      id: 3,
      name: r'installationId',
      type: IsarType.string,
    ),
    r'lastSyncAt': PropertySchema(
      id: 4,
      name: r'lastSyncAt',
      type: IsarType.dateTime,
    ),
    r'lastSyncError': PropertySchema(
      id: 5,
      name: r'lastSyncError',
      type: IsarType.string,
    ),
    r'lastSyncPhase': PropertySchema(
      id: 6,
      name: r'lastSyncPhase',
      type: IsarType.string,
    ),
    r'localEventId': PropertySchema(
      id: 7,
      name: r'localEventId',
      type: IsarType.string,
    ),
    r'phraseId': PropertySchema(
      id: 8,
      name: r'phraseId',
      type: IsarType.string,
    ),
    r'reactionType': PropertySchema(
      id: 9,
      name: r'reactionType',
      type: IsarType.string,
    ),
    r'spaceId': PropertySchema(id: 10, name: r'spaceId', type: IsarType.string),
    r'syncState': PropertySchema(
      id: 11,
      name: r'syncState',
      type: IsarType.string,
    ),
  },
  estimateSize: _interactionEventEntityEstimateSize,
  serialize: _interactionEventEntitySerialize,
  deserialize: _interactionEventEntityDeserialize,
  deserializeProp: _interactionEventEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'eventKey': IndexSchema(
      id: -6167434590247707527,
      name: r'eventKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'eventKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'localEventId': IndexSchema(
      id: -8917523126984297887,
      name: r'localEventId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'localEventId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'spaceId': IndexSchema(
      id: -1779888219436521473,
      name: r'spaceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'spaceId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'activityId': IndexSchema(
      id: 8968520805042838249,
      name: r'activityId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'activityId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'phraseId': IndexSchema(
      id: -1936705100628921048,
      name: r'phraseId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'phraseId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'clientTimestamp': IndexSchema(
      id: 9143486331788672621,
      name: r'clientTimestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'clientTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'syncState': IndexSchema(
      id: -413052077849439895,
      name: r'syncState',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'syncState',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _interactionEventEntityGetId,
  getLinks: _interactionEventEntityGetLinks,
  attach: _interactionEventEntityAttach,
  version: '3.1.0+1',
);

int _interactionEventEntityEstimateSize(
  InteractionEventEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.activityId.length * 3;
  bytesCount += 3 + object.eventKey.length * 3;
  bytesCount += 3 + object.installationId.length * 3;
  {
    final value = object.lastSyncError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastSyncPhase;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.localEventId.length * 3;
  bytesCount += 3 + object.phraseId.length * 3;
  bytesCount += 3 + object.reactionType.length * 3;
  bytesCount += 3 + object.spaceId.length * 3;
  bytesCount += 3 + object.syncState.length * 3;
  return bytesCount;
}

void _interactionEventEntitySerialize(
  InteractionEventEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activityId);
  writer.writeDateTime(offsets[1], object.clientTimestamp);
  writer.writeString(offsets[2], object.eventKey);
  writer.writeString(offsets[3], object.installationId);
  writer.writeDateTime(offsets[4], object.lastSyncAt);
  writer.writeString(offsets[5], object.lastSyncError);
  writer.writeString(offsets[6], object.lastSyncPhase);
  writer.writeString(offsets[7], object.localEventId);
  writer.writeString(offsets[8], object.phraseId);
  writer.writeString(offsets[9], object.reactionType);
  writer.writeString(offsets[10], object.spaceId);
  writer.writeString(offsets[11], object.syncState);
}

InteractionEventEntity _interactionEventEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = InteractionEventEntity();
  object.activityId = reader.readString(offsets[0]);
  object.clientTimestamp = reader.readDateTime(offsets[1]);
  object.eventKey = reader.readString(offsets[2]);
  object.id = id;
  object.installationId = reader.readString(offsets[3]);
  object.lastSyncAt = reader.readDateTimeOrNull(offsets[4]);
  object.lastSyncError = reader.readStringOrNull(offsets[5]);
  object.lastSyncPhase = reader.readStringOrNull(offsets[6]);
  object.localEventId = reader.readString(offsets[7]);
  object.phraseId = reader.readString(offsets[8]);
  object.reactionType = reader.readString(offsets[9]);
  object.spaceId = reader.readString(offsets[10]);
  object.syncState = reader.readString(offsets[11]);
  return object;
}

P _interactionEventEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _interactionEventEntityGetId(InteractionEventEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _interactionEventEntityGetLinks(
  InteractionEventEntity object,
) {
  return [];
}

void _interactionEventEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  InteractionEventEntity object,
) {
  object.id = id;
}

extension InteractionEventEntityByIndex
    on IsarCollection<InteractionEventEntity> {
  Future<InteractionEventEntity?> getByEventKey(String eventKey) {
    return getByIndex(r'eventKey', [eventKey]);
  }

  InteractionEventEntity? getByEventKeySync(String eventKey) {
    return getByIndexSync(r'eventKey', [eventKey]);
  }

  Future<bool> deleteByEventKey(String eventKey) {
    return deleteByIndex(r'eventKey', [eventKey]);
  }

  bool deleteByEventKeySync(String eventKey) {
    return deleteByIndexSync(r'eventKey', [eventKey]);
  }

  Future<List<InteractionEventEntity?>> getAllByEventKey(
    List<String> eventKeyValues,
  ) {
    final values = eventKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'eventKey', values);
  }

  List<InteractionEventEntity?> getAllByEventKeySync(
    List<String> eventKeyValues,
  ) {
    final values = eventKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'eventKey', values);
  }

  Future<int> deleteAllByEventKey(List<String> eventKeyValues) {
    final values = eventKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'eventKey', values);
  }

  int deleteAllByEventKeySync(List<String> eventKeyValues) {
    final values = eventKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'eventKey', values);
  }

  Future<Id> putByEventKey(InteractionEventEntity object) {
    return putByIndex(r'eventKey', object);
  }

  Id putByEventKeySync(InteractionEventEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'eventKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEventKey(List<InteractionEventEntity> objects) {
    return putAllByIndex(r'eventKey', objects);
  }

  List<Id> putAllByEventKeySync(
    List<InteractionEventEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'eventKey', objects, saveLinks: saveLinks);
  }

  Future<InteractionEventEntity?> getByLocalEventId(String localEventId) {
    return getByIndex(r'localEventId', [localEventId]);
  }

  InteractionEventEntity? getByLocalEventIdSync(String localEventId) {
    return getByIndexSync(r'localEventId', [localEventId]);
  }

  Future<bool> deleteByLocalEventId(String localEventId) {
    return deleteByIndex(r'localEventId', [localEventId]);
  }

  bool deleteByLocalEventIdSync(String localEventId) {
    return deleteByIndexSync(r'localEventId', [localEventId]);
  }

  Future<List<InteractionEventEntity?>> getAllByLocalEventId(
    List<String> localEventIdValues,
  ) {
    final values = localEventIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'localEventId', values);
  }

  List<InteractionEventEntity?> getAllByLocalEventIdSync(
    List<String> localEventIdValues,
  ) {
    final values = localEventIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'localEventId', values);
  }

  Future<int> deleteAllByLocalEventId(List<String> localEventIdValues) {
    final values = localEventIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'localEventId', values);
  }

  int deleteAllByLocalEventIdSync(List<String> localEventIdValues) {
    final values = localEventIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'localEventId', values);
  }

  Future<Id> putByLocalEventId(InteractionEventEntity object) {
    return putByIndex(r'localEventId', object);
  }

  Id putByLocalEventIdSync(
    InteractionEventEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'localEventId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLocalEventId(List<InteractionEventEntity> objects) {
    return putAllByIndex(r'localEventId', objects);
  }

  List<Id> putAllByLocalEventIdSync(
    List<InteractionEventEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'localEventId', objects, saveLinks: saveLinks);
  }
}

extension InteractionEventEntityQueryWhereSort
    on QueryBuilder<InteractionEventEntity, InteractionEventEntity, QWhere> {
  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterWhere>
  anyClientTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'clientTimestamp'),
      );
    });
  }
}

extension InteractionEventEntityQueryWhere
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QWhereClause
        > {
  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  eventKeyEqualTo(String eventKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'eventKey', value: [eventKey]),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  eventKeyNotEqualTo(String eventKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventKey',
                lower: [],
                upper: [eventKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventKey',
                lower: [eventKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventKey',
                lower: [eventKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventKey',
                lower: [],
                upper: [eventKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  localEventIdEqualTo(String localEventId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'localEventId',
          value: [localEventId],
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  localEventIdNotEqualTo(String localEventId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'localEventId',
                lower: [],
                upper: [localEventId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'localEventId',
                lower: [localEventId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'localEventId',
                lower: [localEventId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'localEventId',
                lower: [],
                upper: [localEventId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  spaceIdEqualTo(String spaceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'spaceId', value: [spaceId]),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  spaceIdNotEqualTo(String spaceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'spaceId',
                lower: [],
                upper: [spaceId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'spaceId',
                lower: [spaceId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'spaceId',
                lower: [spaceId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'spaceId',
                lower: [],
                upper: [spaceId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  activityIdEqualTo(String activityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'activityId', value: [activityId]),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  activityIdNotEqualTo(String activityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'activityId',
                lower: [],
                upper: [activityId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'activityId',
                lower: [activityId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'activityId',
                lower: [activityId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'activityId',
                lower: [],
                upper: [activityId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  phraseIdEqualTo(String phraseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'phraseId', value: [phraseId]),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  phraseIdNotEqualTo(String phraseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'phraseId',
                lower: [],
                upper: [phraseId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'phraseId',
                lower: [phraseId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'phraseId',
                lower: [phraseId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'phraseId',
                lower: [],
                upper: [phraseId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  clientTimestampEqualTo(DateTime clientTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'clientTimestamp',
          value: [clientTimestamp],
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  clientTimestampNotEqualTo(DateTime clientTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clientTimestamp',
                lower: [],
                upper: [clientTimestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clientTimestamp',
                lower: [clientTimestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clientTimestamp',
                lower: [clientTimestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clientTimestamp',
                lower: [],
                upper: [clientTimestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  clientTimestampGreaterThan(DateTime clientTimestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'clientTimestamp',
          lower: [clientTimestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  clientTimestampLessThan(DateTime clientTimestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'clientTimestamp',
          lower: [],
          upper: [clientTimestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  clientTimestampBetween(
    DateTime lowerClientTimestamp,
    DateTime upperClientTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'clientTimestamp',
          lower: [lowerClientTimestamp],
          includeLower: includeLower,
          upper: [upperClientTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  syncStateEqualTo(String syncState) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'syncState', value: [syncState]),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterWhereClause
  >
  syncStateNotEqualTo(String syncState) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncState',
                lower: [],
                upper: [syncState],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncState',
                lower: [syncState],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncState',
                lower: [syncState],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'syncState',
                lower: [],
                upper: [syncState],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension InteractionEventEntityQueryFilter
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QFilterCondition
        > {
  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'activityId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'activityId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  activityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'activityId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  clientTimestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'clientTimestamp', value: value),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  clientTimestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'clientTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  clientTimestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'clientTimestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  clientTimestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'clientTimestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'eventKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'eventKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'eventKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eventKey', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  eventKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'eventKey', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'installationId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'installationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'installationId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'installationId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  installationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'installationId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncAt'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncAt'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncAt', value: value),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncError'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncError'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncError',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastSyncError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastSyncError',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncError', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastSyncError', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncPhase'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncPhase'),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncPhase',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastSyncPhase',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastSyncPhase',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncPhase', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  lastSyncPhaseIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastSyncPhase', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'localEventId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'localEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'localEventId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'localEventId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  localEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'localEventId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'phraseId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'phraseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'phraseId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'phraseId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  phraseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'phraseId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reactionType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'reactionType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'reactionType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reactionType', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  reactionTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'reactionType', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'spaceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'spaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'spaceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'spaceId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  spaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'spaceId', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'syncState',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'syncState',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'syncState',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncState', value: ''),
      );
    });
  }

  QueryBuilder<
    InteractionEventEntity,
    InteractionEventEntity,
    QAfterFilterCondition
  >
  syncStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'syncState', value: ''),
      );
    });
  }
}

extension InteractionEventEntityQueryObject
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QFilterCondition
        > {}

extension InteractionEventEntityQueryLinks
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QFilterCondition
        > {}

extension InteractionEventEntityQuerySortBy
    on QueryBuilder<InteractionEventEntity, InteractionEventEntity, QSortBy> {
  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByClientTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientTimestamp', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByClientTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientTimestamp', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByEventKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByEventKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByInstallationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByInstallationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncError', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncError', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncPhase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncPhase', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLastSyncPhaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncPhase', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLocalEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByLocalEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByPhraseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phraseId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByPhraseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phraseId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByReactionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionType', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortByReactionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionType', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortBySpaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spaceId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortBySpaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spaceId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  sortBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }
}

extension InteractionEventEntityQuerySortThenBy
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QSortThenBy
        > {
  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByClientTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientTimestamp', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByClientTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientTimestamp', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByEventKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByEventKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByInstallationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByInstallationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncError', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncError', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncPhase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncPhase', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLastSyncPhaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncPhase', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLocalEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByLocalEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByPhraseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phraseId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByPhraseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phraseId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByReactionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionType', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenByReactionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reactionType', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenBySpaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spaceId', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenBySpaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spaceId', Sort.desc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterSortBy>
  thenBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }
}

extension InteractionEventEntityQueryWhereDistinct
    on QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct> {
  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByActivityId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByClientTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientTimestamp');
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByEventKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByInstallationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'installationId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncAt');
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByLastSyncError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastSyncError',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByLastSyncPhase({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastSyncPhase',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByLocalEventId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localEventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByPhraseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'phraseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctByReactionType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reactionType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctBySpaceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'spaceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InteractionEventEntity, InteractionEventEntity, QDistinct>
  distinctBySyncState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncState', caseSensitive: caseSensitive);
    });
  }
}

extension InteractionEventEntityQueryProperty
    on
        QueryBuilder<
          InteractionEventEntity,
          InteractionEventEntity,
          QQueryProperty
        > {
  QueryBuilder<InteractionEventEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  activityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityId');
    });
  }

  QueryBuilder<InteractionEventEntity, DateTime, QQueryOperations>
  clientTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientTimestamp');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  eventKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventKey');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  installationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'installationId');
    });
  }

  QueryBuilder<InteractionEventEntity, DateTime?, QQueryOperations>
  lastSyncAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncAt');
    });
  }

  QueryBuilder<InteractionEventEntity, String?, QQueryOperations>
  lastSyncErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncError');
    });
  }

  QueryBuilder<InteractionEventEntity, String?, QQueryOperations>
  lastSyncPhaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncPhase');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  localEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localEventId');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  phraseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'phraseId');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  reactionTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reactionType');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  spaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'spaceId');
    });
  }

  QueryBuilder<InteractionEventEntity, String, QQueryOperations>
  syncStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncState');
    });
  }
}
