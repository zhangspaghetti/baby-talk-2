// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../../features/mentor/data/local/mentor_fact_event_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMentorFactEventEntityCollection on Isar {
  IsarCollection<MentorFactEventEntity> get mentorFactEventEntitys =>
      this.collection();
}

const MentorFactEventEntitySchema = CollectionSchema(
  name: r'MentorFactEventEntity',
  id: -3150522105141414434,
  properties: {
    r'contextFallbackUsed': PropertySchema(
      id: 0,
      name: r'contextFallbackUsed',
      type: IsarType.bool,
    ),
    r'correlationId': PropertySchema(
      id: 1,
      name: r'correlationId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'eventKey': PropertySchema(
      id: 3,
      name: r'eventKey',
      type: IsarType.string,
    ),
    r'eventType': PropertySchema(
      id: 4,
      name: r'eventType',
      type: IsarType.string,
    ),
    r'installationId': PropertySchema(
      id: 5,
      name: r'installationId',
      type: IsarType.string,
    ),
    r'localEventId': PropertySchema(
      id: 6,
      name: r'localEventId',
      type: IsarType.string,
    ),
    r'phase': PropertySchema(
      id: 7,
      name: r'phase',
      type: IsarType.string,
    ),
    r'redactedSummary': PropertySchema(
      id: 8,
      name: r'redactedSummary',
      type: IsarType.string,
    ),
    r'retryable': PropertySchema(
      id: 9,
      name: r'retryable',
      type: IsarType.bool,
    ),
    r'visibleDetail': PropertySchema(
      id: 10,
      name: r'visibleDetail',
      type: IsarType.string,
    ),
    r'visibleStatus': PropertySchema(
      id: 11,
      name: r'visibleStatus',
      type: IsarType.string,
    )
  },
  estimateSize: _mentorFactEventEntityEstimateSize,
  serialize: _mentorFactEventEntitySerialize,
  deserialize: _mentorFactEventEntityDeserialize,
  deserializeProp: _mentorFactEventEntityDeserializeProp,
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
        )
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
        )
      ],
    ),
    r'eventType': IndexSchema(
      id: -3849237371187389498,
      name: r'eventType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'eventType',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _mentorFactEventEntityGetId,
  getLinks: _mentorFactEventEntityGetLinks,
  attach: _mentorFactEventEntityAttach,
  version: '3.1.0+1',
);

int _mentorFactEventEntityEstimateSize(
  MentorFactEventEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.correlationId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.eventKey.length * 3;
  bytesCount += 3 + object.eventType.length * 3;
  bytesCount += 3 + object.installationId.length * 3;
  bytesCount += 3 + object.localEventId.length * 3;
  bytesCount += 3 + object.phase.length * 3;
  {
    final value = object.redactedSummary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.visibleDetail;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.visibleStatus;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _mentorFactEventEntitySerialize(
  MentorFactEventEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.contextFallbackUsed);
  writer.writeString(offsets[1], object.correlationId);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.eventKey);
  writer.writeString(offsets[4], object.eventType);
  writer.writeString(offsets[5], object.installationId);
  writer.writeString(offsets[6], object.localEventId);
  writer.writeString(offsets[7], object.phase);
  writer.writeString(offsets[8], object.redactedSummary);
  writer.writeBool(offsets[9], object.retryable);
  writer.writeString(offsets[10], object.visibleDetail);
  writer.writeString(offsets[11], object.visibleStatus);
}

MentorFactEventEntity _mentorFactEventEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MentorFactEventEntity();
  object.contextFallbackUsed = reader.readBool(offsets[0]);
  object.correlationId = reader.readStringOrNull(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.eventKey = reader.readString(offsets[3]);
  object.eventType = reader.readString(offsets[4]);
  object.id = id;
  object.installationId = reader.readString(offsets[5]);
  object.localEventId = reader.readString(offsets[6]);
  object.phase = reader.readString(offsets[7]);
  object.redactedSummary = reader.readStringOrNull(offsets[8]);
  object.retryable = reader.readBool(offsets[9]);
  object.visibleDetail = reader.readStringOrNull(offsets[10]);
  object.visibleStatus = reader.readStringOrNull(offsets[11]);
  return object;
}

P _mentorFactEventEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mentorFactEventEntityGetId(MentorFactEventEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mentorFactEventEntityGetLinks(
    MentorFactEventEntity object) {
  return [];
}

void _mentorFactEventEntityAttach(
    IsarCollection<dynamic> col, Id id, MentorFactEventEntity object) {
  object.id = id;
}

extension MentorFactEventEntityByIndex
    on IsarCollection<MentorFactEventEntity> {
  Future<MentorFactEventEntity?> getByEventKey(String eventKey) {
    return getByIndex(r'eventKey', [eventKey]);
  }

  MentorFactEventEntity? getByEventKeySync(String eventKey) {
    return getByIndexSync(r'eventKey', [eventKey]);
  }

  Future<bool> deleteByEventKey(String eventKey) {
    return deleteByIndex(r'eventKey', [eventKey]);
  }

  bool deleteByEventKeySync(String eventKey) {
    return deleteByIndexSync(r'eventKey', [eventKey]);
  }

  Future<List<MentorFactEventEntity?>> getAllByEventKey(
      List<String> eventKeyValues) {
    final values = eventKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'eventKey', values);
  }

  List<MentorFactEventEntity?> getAllByEventKeySync(
      List<String> eventKeyValues) {
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

  Future<Id> putByEventKey(MentorFactEventEntity object) {
    return putByIndex(r'eventKey', object);
  }

  Id putByEventKeySync(MentorFactEventEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'eventKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEventKey(List<MentorFactEventEntity> objects) {
    return putAllByIndex(r'eventKey', objects);
  }

  List<Id> putAllByEventKeySync(List<MentorFactEventEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'eventKey', objects, saveLinks: saveLinks);
  }

  Future<MentorFactEventEntity?> getByLocalEventId(String localEventId) {
    return getByIndex(r'localEventId', [localEventId]);
  }

  MentorFactEventEntity? getByLocalEventIdSync(String localEventId) {
    return getByIndexSync(r'localEventId', [localEventId]);
  }

  Future<bool> deleteByLocalEventId(String localEventId) {
    return deleteByIndex(r'localEventId', [localEventId]);
  }

  bool deleteByLocalEventIdSync(String localEventId) {
    return deleteByIndexSync(r'localEventId', [localEventId]);
  }

  Future<List<MentorFactEventEntity?>> getAllByLocalEventId(
      List<String> localEventIdValues) {
    final values = localEventIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'localEventId', values);
  }

  List<MentorFactEventEntity?> getAllByLocalEventIdSync(
      List<String> localEventIdValues) {
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

  Future<Id> putByLocalEventId(MentorFactEventEntity object) {
    return putByIndex(r'localEventId', object);
  }

  Id putByLocalEventIdSync(MentorFactEventEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'localEventId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLocalEventId(List<MentorFactEventEntity> objects) {
    return putAllByIndex(r'localEventId', objects);
  }

  List<Id> putAllByLocalEventIdSync(List<MentorFactEventEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'localEventId', objects, saveLinks: saveLinks);
  }
}

extension MentorFactEventEntityQueryWhereSort
    on QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QWhere> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension MentorFactEventEntityQueryWhere on QueryBuilder<MentorFactEventEntity,
    MentorFactEventEntity, QWhereClause> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
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

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      eventKeyEqualTo(String eventKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'eventKey',
        value: [eventKey],
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      eventKeyNotEqualTo(String eventKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventKey',
              lower: [],
              upper: [eventKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventKey',
              lower: [eventKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventKey',
              lower: [eventKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventKey',
              lower: [],
              upper: [eventKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      localEventIdEqualTo(String localEventId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localEventId',
        value: [localEventId],
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      localEventIdNotEqualTo(String localEventId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localEventId',
              lower: [],
              upper: [localEventId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localEventId',
              lower: [localEventId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localEventId',
              lower: [localEventId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localEventId',
              lower: [],
              upper: [localEventId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      eventTypeEqualTo(String eventType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'eventType',
        value: [eventType],
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      eventTypeNotEqualTo(String eventType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventType',
              lower: [],
              upper: [eventType],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventType',
              lower: [eventType],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventType',
              lower: [eventType],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventType',
              lower: [],
              upper: [eventType],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MentorFactEventEntityQueryFilter on QueryBuilder<
    MentorFactEventEntity, MentorFactEventEntity, QFilterCondition> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> contextFallbackUsedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contextFallbackUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'correlationId',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'correlationId',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'correlationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      correlationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'correlationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      correlationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'correlationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'correlationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> correlationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'correlationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      eventKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      eventKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      eventTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      eventTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventType',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> eventTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventType',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'installationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      installationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'installationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      installationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'installationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'installationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> installationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'installationId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localEventId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      localEventIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localEventId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      localEventIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localEventId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localEventId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> localEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localEventId',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'phase',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      phaseContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'phase',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      phaseMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'phase',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'phase',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> phaseIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'phase',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'redactedSummary',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'redactedSummary',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'redactedSummary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      redactedSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'redactedSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      redactedSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'redactedSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'redactedSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> redactedSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'redactedSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> retryableEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retryable',
        value: value,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'visibleDetail',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'visibleDetail',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'visibleDetail',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      visibleDetailContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'visibleDetail',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      visibleDetailMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'visibleDetail',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'visibleDetail',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleDetailIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'visibleDetail',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'visibleStatus',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'visibleStatus',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'visibleStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      visibleStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'visibleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
          QAfterFilterCondition>
      visibleStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'visibleStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'visibleStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity,
      QAfterFilterCondition> visibleStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'visibleStatus',
        value: '',
      ));
    });
  }
}

extension MentorFactEventEntityQueryObject on QueryBuilder<
    MentorFactEventEntity, MentorFactEventEntity, QFilterCondition> {}

extension MentorFactEventEntityQueryLinks on QueryBuilder<MentorFactEventEntity,
    MentorFactEventEntity, QFilterCondition> {}

extension MentorFactEventEntityQuerySortBy
    on QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QSortBy> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByContextFallbackUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextFallbackUsed', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByContextFallbackUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextFallbackUsed', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByCorrelationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByCorrelationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByEventKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByEventKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByEventType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventType', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByEventTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventType', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByInstallationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByInstallationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByLocalEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByLocalEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByPhase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phase', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByPhaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phase', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByRedactedSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redactedSummary', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByRedactedSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redactedSummary', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryable', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByRetryableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryable', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByVisibleDetail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleDetail', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByVisibleDetailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleDetail', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByVisibleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleStatus', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      sortByVisibleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleStatus', Sort.desc);
    });
  }
}

extension MentorFactEventEntityQuerySortThenBy
    on QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QSortThenBy> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByContextFallbackUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextFallbackUsed', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByContextFallbackUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextFallbackUsed', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByCorrelationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByCorrelationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correlationId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByEventKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByEventKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventKey', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByEventType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventType', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByEventTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventType', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByInstallationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByInstallationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installationId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByLocalEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByLocalEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localEventId', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByPhase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phase', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByPhaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phase', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByRedactedSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redactedSummary', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByRedactedSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redactedSummary', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryable', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByRetryableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryable', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByVisibleDetail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleDetail', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByVisibleDetailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleDetail', Sort.desc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByVisibleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleStatus', Sort.asc);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QAfterSortBy>
      thenByVisibleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibleStatus', Sort.desc);
    });
  }
}

extension MentorFactEventEntityQueryWhereDistinct
    on QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct> {
  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByContextFallbackUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contextFallbackUsed');
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByCorrelationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'correlationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByEventKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByEventType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByInstallationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'installationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByLocalEventId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localEventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByPhase({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'phase', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByRedactedSummary({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'redactedSummary',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryable');
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByVisibleDetail({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visibleDetail',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MentorFactEventEntity, MentorFactEventEntity, QDistinct>
      distinctByVisibleStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visibleStatus',
          caseSensitive: caseSensitive);
    });
  }
}

extension MentorFactEventEntityQueryProperty on QueryBuilder<
    MentorFactEventEntity, MentorFactEventEntity, QQueryProperty> {
  QueryBuilder<MentorFactEventEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MentorFactEventEntity, bool, QQueryOperations>
      contextFallbackUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contextFallbackUsed');
    });
  }

  QueryBuilder<MentorFactEventEntity, String?, QQueryOperations>
      correlationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'correlationId');
    });
  }

  QueryBuilder<MentorFactEventEntity, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MentorFactEventEntity, String, QQueryOperations>
      eventKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventKey');
    });
  }

  QueryBuilder<MentorFactEventEntity, String, QQueryOperations>
      eventTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventType');
    });
  }

  QueryBuilder<MentorFactEventEntity, String, QQueryOperations>
      installationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'installationId');
    });
  }

  QueryBuilder<MentorFactEventEntity, String, QQueryOperations>
      localEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localEventId');
    });
  }

  QueryBuilder<MentorFactEventEntity, String, QQueryOperations>
      phaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'phase');
    });
  }

  QueryBuilder<MentorFactEventEntity, String?, QQueryOperations>
      redactedSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'redactedSummary');
    });
  }

  QueryBuilder<MentorFactEventEntity, bool, QQueryOperations>
      retryableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryable');
    });
  }

  QueryBuilder<MentorFactEventEntity, String?, QQueryOperations>
      visibleDetailProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visibleDetail');
    });
  }

  QueryBuilder<MentorFactEventEntity, String?, QQueryOperations>
      visibleStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visibleStatus');
    });
  }
}
