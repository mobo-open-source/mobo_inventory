

part of 'company_entity.dart';

extension GetCompanyEntityCollection on Isar {
  IsarCollection<CompanyEntity> get companyEntitys => this.collection();
}

const CompanyEntitySchema = CollectionSchema(
  name: r'CompanyEntity',
  id: 7732127242476929416,
  properties: {
    r'companyId': PropertySchema(
      id: 0,
      name: r'companyId',
      type: IsarType.long,
    ),
    r'name': PropertySchema(id: 1, name: r'name', type: IsarType.string),
    r'nameLower': PropertySchema(
      id: 2,
      name: r'nameLower',
      type: IsarType.string,
    ),
  },

  estimateSize: _companyEntityEstimateSize,
  serialize: _companyEntitySerialize,
  deserialize: _companyEntityDeserialize,
  deserializeProp: _companyEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'companyId': IndexSchema(
      id: 482756417767355356,
      name: r'companyId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'companyId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _companyEntityGetId,
  getLinks: _companyEntityGetLinks,
  attach: _companyEntityAttach,
  version: '3.3.0',
);

int _companyEntityEstimateSize(
  CompanyEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.nameLower.length * 3;
  return bytesCount;
}

void _companyEntitySerialize(
  CompanyEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.companyId);
  writer.writeString(offsets[1], object.name);
  writer.writeString(offsets[2], object.nameLower);
}

CompanyEntity _companyEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CompanyEntity();
  object.companyId = reader.readLong(offsets[0]);
  object.id = id;
  object.name = reader.readString(offsets[1]);
  object.nameLower = reader.readString(offsets[2]);
  return object;
}

P _companyEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _companyEntityGetId(CompanyEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _companyEntityGetLinks(CompanyEntity object) {
  return [];
}

void _companyEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  CompanyEntity object,
) {
  object.id = id;
}

extension CompanyEntityByIndex on IsarCollection<CompanyEntity> {
  Future<CompanyEntity?> getByCompanyId(int companyId) {
    return getByIndex(r'companyId', [companyId]);
  }

  CompanyEntity? getByCompanyIdSync(int companyId) {
    return getByIndexSync(r'companyId', [companyId]);
  }

  Future<bool> deleteByCompanyId(int companyId) {
    return deleteByIndex(r'companyId', [companyId]);
  }

  bool deleteByCompanyIdSync(int companyId) {
    return deleteByIndexSync(r'companyId', [companyId]);
  }

  Future<List<CompanyEntity?>> getAllByCompanyId(List<int> companyIdValues) {
    final values = companyIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'companyId', values);
  }

  List<CompanyEntity?> getAllByCompanyIdSync(List<int> companyIdValues) {
    final values = companyIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'companyId', values);
  }

  Future<int> deleteAllByCompanyId(List<int> companyIdValues) {
    final values = companyIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'companyId', values);
  }

  int deleteAllByCompanyIdSync(List<int> companyIdValues) {
    final values = companyIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'companyId', values);
  }

  Future<Id> putByCompanyId(CompanyEntity object) {
    return putByIndex(r'companyId', object);
  }

  Id putByCompanyIdSync(CompanyEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'companyId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCompanyId(List<CompanyEntity> objects) {
    return putAllByIndex(r'companyId', objects);
  }

  List<Id> putAllByCompanyIdSync(
    List<CompanyEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'companyId', objects, saveLinks: saveLinks);
  }
}

extension CompanyEntityQueryWhereSort
    on QueryBuilder<CompanyEntity, CompanyEntity, QWhere> {
  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhere> anyCompanyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'companyId'),
      );
    });
  }
}

extension CompanyEntityQueryWhere
    on QueryBuilder<CompanyEntity, CompanyEntity, QWhereClause> {
  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause>
  companyIdEqualTo(int companyId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'companyId', value: [companyId]),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause>
  companyIdNotEqualTo(int companyId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'companyId',
                lower: [],
                upper: [companyId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'companyId',
                lower: [companyId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'companyId',
                lower: [companyId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'companyId',
                lower: [],
                upper: [companyId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause>
  companyIdGreaterThan(int companyId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'companyId',
          lower: [companyId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause>
  companyIdLessThan(int companyId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'companyId',
          lower: [],
          upper: [companyId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause>
  companyIdBetween(
    int lowerCompanyId,
    int upperCompanyId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'companyId',
          lower: [lowerCompanyId],
          includeLower: includeLower,
          upper: [upperCompanyId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> nameEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: [name]),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterWhereClause> nameNotEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension CompanyEntityQueryFilter
    on QueryBuilder<CompanyEntity, CompanyEntity, QFilterCondition> {
  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  companyIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'companyId', value: value),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  companyIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'companyId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  companyIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'companyId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  companyIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'companyId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
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

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nameLower',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'nameLower',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'nameLower',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nameLower', value: ''),
      );
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterFilterCondition>
  nameLowerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nameLower', value: ''),
      );
    });
  }
}

extension CompanyEntityQueryObject
    on QueryBuilder<CompanyEntity, CompanyEntity, QFilterCondition> {}

extension CompanyEntityQueryLinks
    on QueryBuilder<CompanyEntity, CompanyEntity, QFilterCondition> {}

extension CompanyEntityQuerySortBy
    on QueryBuilder<CompanyEntity, CompanyEntity, QSortBy> {
  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> sortByCompanyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'companyId', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy>
  sortByCompanyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'companyId', Sort.desc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> sortByNameLower() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLower', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy>
  sortByNameLowerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLower', Sort.desc);
    });
  }
}

extension CompanyEntityQuerySortThenBy
    on QueryBuilder<CompanyEntity, CompanyEntity, QSortThenBy> {
  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenByCompanyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'companyId', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy>
  thenByCompanyIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'companyId', Sort.desc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy> thenByNameLower() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLower', Sort.asc);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QAfterSortBy>
  thenByNameLowerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLower', Sort.desc);
    });
  }
}

extension CompanyEntityQueryWhereDistinct
    on QueryBuilder<CompanyEntity, CompanyEntity, QDistinct> {
  QueryBuilder<CompanyEntity, CompanyEntity, QDistinct> distinctByCompanyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'companyId');
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CompanyEntity, CompanyEntity, QDistinct> distinctByNameLower({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nameLower', caseSensitive: caseSensitive);
    });
  }
}

extension CompanyEntityQueryProperty
    on QueryBuilder<CompanyEntity, CompanyEntity, QQueryProperty> {
  QueryBuilder<CompanyEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CompanyEntity, int, QQueryOperations> companyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'companyId');
    });
  }

  QueryBuilder<CompanyEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<CompanyEntity, String, QQueryOperations> nameLowerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nameLower');
    });
  }
}
