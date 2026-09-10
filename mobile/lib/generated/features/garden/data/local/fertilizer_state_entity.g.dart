// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../../features/garden/data/local/fertilizer_state_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFertilizerStateEntityCollection on Isar {
  IsarCollection<FertilizerStateEntity> get fertilizerStateEntitys =>
      this.collection();
}

const FertilizerStateEntitySchema = CollectionSchema(
  name: r'FertilizerStateEntity',
  id: 7047416687553572393,
  properties: {
    r'appliedCount': PropertySchema(
      id: 0,
      name: r'appliedCount',
      type: IsarType.long,
    ),
    r'claimedEventKeys': PropertySchema(
      id: 1,
      name: r'claimedEventKeys',
      type: IsarType.stringList,
    ),
    r'lastAppliedAt': PropertySchema(
      id: 2,
      name: r'lastAppliedAt',
      type: IsarType.dateTime,
    ),
    r'lastClaimedAt': PropertySchema(
      id: 3,
      name: r'lastClaimedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _fertilizerStateEntityEstimateSize,
  serialize: _fertilizerStateEntitySerialize,
  deserialize: _fertilizerStateEntityDeserialize,
  deserializeProp: _fertilizerStateEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _fertilizerStateEntityGetId,
  getLinks: _fertilizerStateEntityGetLinks,
  attach: _fertilizerStateEntityAttach,
  version: '3.1.0+1',
);

int _fertilizerStateEntityEstimateSize(
  FertilizerStateEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.claimedEventKeys.length * 3;
  {
    for (var i = 0; i < object.claimedEventKeys.length; i++) {
      final value = object.claimedEventKeys[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _fertilizerStateEntitySerialize(
  FertilizerStateEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.appliedCount);
  writer.writeStringList(offsets[1], object.claimedEventKeys);
  writer.writeDateTime(offsets[2], object.lastAppliedAt);
  writer.writeDateTime(offsets[3], object.lastClaimedAt);
}

FertilizerStateEntity _fertilizerStateEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FertilizerStateEntity();
  object.appliedCount = reader.readLong(offsets[0]);
  object.claimedEventKeys = reader.readStringList(offsets[1]) ?? [];
  object.id = id;
  object.lastAppliedAt = reader.readDateTimeOrNull(offsets[2]);
  object.lastClaimedAt = reader.readDateTimeOrNull(offsets[3]);
  return object;
}

P _fertilizerStateEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringList(offset) ?? []) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _fertilizerStateEntityGetId(FertilizerStateEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _fertilizerStateEntityGetLinks(
  FertilizerStateEntity object,
) {
  return [];
}

void _fertilizerStateEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  FertilizerStateEntity object,
) {
  object.id = id;
}

extension FertilizerStateEntityQueryWhereSort
    on QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QWhere> {
  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FertilizerStateEntityQueryWhere
    on
        QueryBuilder<
          FertilizerStateEntity,
          FertilizerStateEntity,
          QWhereClause
        > {
  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhereClause>
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

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterWhereClause>
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
}

extension FertilizerStateEntityQueryFilter
    on
        QueryBuilder<
          FertilizerStateEntity,
          FertilizerStateEntity,
          QFilterCondition
        > {
  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  appliedCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'appliedCount', value: value),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  appliedCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'appliedCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  appliedCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'appliedCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  appliedCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'appliedCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'claimedEventKeys',
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
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'claimedEventKeys',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'claimedEventKeys',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'claimedEventKeys', value: ''),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'claimedEventKeys', value: ''),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'claimedEventKeys', length, true, length, true);
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'claimedEventKeys', 0, true, 0, true);
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'claimedEventKeys', 0, false, 999999, true);
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'claimedEventKeys', 0, true, length, include);
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'claimedEventKeys',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  claimedEventKeysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'claimedEventKeys',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
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
    FertilizerStateEntity,
    FertilizerStateEntity,
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
    FertilizerStateEntity,
    FertilizerStateEntity,
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
    FertilizerStateEntity,
    FertilizerStateEntity,
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
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastAppliedAt'),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastAppliedAt'),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastAppliedAt', value: value),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastAppliedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastAppliedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastAppliedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastAppliedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastClaimedAt'),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastClaimedAt'),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastClaimedAt', value: value),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastClaimedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastClaimedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    FertilizerStateEntity,
    FertilizerStateEntity,
    QAfterFilterCondition
  >
  lastClaimedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastClaimedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension FertilizerStateEntityQueryObject
    on
        QueryBuilder<
          FertilizerStateEntity,
          FertilizerStateEntity,
          QFilterCondition
        > {}

extension FertilizerStateEntityQueryLinks
    on
        QueryBuilder<
          FertilizerStateEntity,
          FertilizerStateEntity,
          QFilterCondition
        > {}

extension FertilizerStateEntityQuerySortBy
    on QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QSortBy> {
  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByAppliedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedCount', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByAppliedCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedCount', Sort.desc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByLastAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedAt', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByLastAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedAt', Sort.desc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByLastClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastClaimedAt', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  sortByLastClaimedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastClaimedAt', Sort.desc);
    });
  }
}

extension FertilizerStateEntityQuerySortThenBy
    on QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QSortThenBy> {
  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByAppliedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedCount', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByAppliedCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedCount', Sort.desc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByLastAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedAt', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByLastAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedAt', Sort.desc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByLastClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastClaimedAt', Sort.asc);
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QAfterSortBy>
  thenByLastClaimedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastClaimedAt', Sort.desc);
    });
  }
}

extension FertilizerStateEntityQueryWhereDistinct
    on QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QDistinct> {
  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QDistinct>
  distinctByAppliedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appliedCount');
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QDistinct>
  distinctByClaimedEventKeys() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'claimedEventKeys');
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QDistinct>
  distinctByLastAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAppliedAt');
    });
  }

  QueryBuilder<FertilizerStateEntity, FertilizerStateEntity, QDistinct>
  distinctByLastClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastClaimedAt');
    });
  }
}

extension FertilizerStateEntityQueryProperty
    on
        QueryBuilder<
          FertilizerStateEntity,
          FertilizerStateEntity,
          QQueryProperty
        > {
  QueryBuilder<FertilizerStateEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FertilizerStateEntity, int, QQueryOperations>
  appliedCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appliedCount');
    });
  }

  QueryBuilder<FertilizerStateEntity, List<String>, QQueryOperations>
  claimedEventKeysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'claimedEventKeys');
    });
  }

  QueryBuilder<FertilizerStateEntity, DateTime?, QQueryOperations>
  lastAppliedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAppliedAt');
    });
  }

  QueryBuilder<FertilizerStateEntity, DateTime?, QQueryOperations>
  lastClaimedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastClaimedAt');
    });
  }
}
