// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../../features/settings/data/local/settings_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSettingsEntityCollection on Isar {
  IsarCollection<SettingsEntity> get settingsEntitys => this.collection();
}

const SettingsEntitySchema = CollectionSchema(
  name: r'SettingsEntity',
  id: -7271317039764597112,
  properties: {
    r'lastModifiedAt': PropertySchema(
      id: 0,
      name: r'lastModifiedAt',
      type: IsarType.dateTime,
    ),
    r'snapshotJson': PropertySchema(
      id: 1,
      name: r'snapshotJson',
      type: IsarType.string,
    ),
    r'version': PropertySchema(id: 2, name: r'version', type: IsarType.long),
  },
  estimateSize: _settingsEntityEstimateSize,
  serialize: _settingsEntitySerialize,
  deserialize: _settingsEntityDeserialize,
  deserializeProp: _settingsEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _settingsEntityGetId,
  getLinks: _settingsEntityGetLinks,
  attach: _settingsEntityAttach,
  version: '3.1.0+1',
);

int _settingsEntityEstimateSize(
  SettingsEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.snapshotJson.length * 3;
  return bytesCount;
}

void _settingsEntitySerialize(
  SettingsEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastModifiedAt);
  writer.writeString(offsets[1], object.snapshotJson);
  writer.writeLong(offsets[2], object.version);
}

SettingsEntity _settingsEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SettingsEntity();
  object.id = id;
  object.lastModifiedAt = reader.readDateTimeOrNull(offsets[0]);
  object.snapshotJson = reader.readString(offsets[1]);
  object.version = reader.readLong(offsets[2]);
  return object;
}

P _settingsEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _settingsEntityGetId(SettingsEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _settingsEntityGetLinks(SettingsEntity object) {
  return [];
}

void _settingsEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  SettingsEntity object,
) {
  object.id = id;
}

extension SettingsEntityQueryWhereSort
    on QueryBuilder<SettingsEntity, SettingsEntity, QWhere> {
  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SettingsEntityQueryWhere
    on QueryBuilder<SettingsEntity, SettingsEntity, QWhereClause> {
  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterWhereClause> idBetween(
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

extension SettingsEntityQueryFilter
    on QueryBuilder<SettingsEntity, SettingsEntity, QFilterCondition> {
  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
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

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
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

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastModifiedAt'),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastModifiedAt'),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastModifiedAt', value: value),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastModifiedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastModifiedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  lastModifiedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastModifiedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'snapshotJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'snapshotJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'snapshotJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snapshotJson', value: ''),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  snapshotJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'snapshotJson', value: ''),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: value),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  versionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  versionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterFilterCondition>
  versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SettingsEntityQueryObject
    on QueryBuilder<SettingsEntity, SettingsEntity, QFilterCondition> {}

extension SettingsEntityQueryLinks
    on QueryBuilder<SettingsEntity, SettingsEntity, QFilterCondition> {}

extension SettingsEntityQuerySortBy
    on QueryBuilder<SettingsEntity, SettingsEntity, QSortBy> {
  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  sortByLastModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  sortByLastModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  sortBySnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotJson', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  sortBySnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotJson', Sort.desc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension SettingsEntityQuerySortThenBy
    on QueryBuilder<SettingsEntity, SettingsEntity, QSortThenBy> {
  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  thenByLastModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  thenByLastModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  thenBySnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotJson', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  thenBySnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotJson', Sort.desc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QAfterSortBy>
  thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension SettingsEntityQueryWhereDistinct
    on QueryBuilder<SettingsEntity, SettingsEntity, QDistinct> {
  QueryBuilder<SettingsEntity, SettingsEntity, QDistinct>
  distinctByLastModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModifiedAt');
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QDistinct>
  distinctBySnapshotJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snapshotJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SettingsEntity, SettingsEntity, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension SettingsEntityQueryProperty
    on QueryBuilder<SettingsEntity, SettingsEntity, QQueryProperty> {
  QueryBuilder<SettingsEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SettingsEntity, DateTime?, QQueryOperations>
  lastModifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModifiedAt');
    });
  }

  QueryBuilder<SettingsEntity, String, QQueryOperations>
  snapshotJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snapshotJson');
    });
  }

  QueryBuilder<SettingsEntity, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
