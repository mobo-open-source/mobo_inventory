

part of 'inventory_product_isar.dart';

extension GetInventoryProductEntityCollection on Isar {
  IsarCollection<InventoryProductEntity> get inventoryProductEntitys =>
      this.collection();
}

const InventoryProductEntitySchema = CollectionSchema(
  name: r'InventoryProductEntity',
  id: -9039323013606236053,
  properties: {
    r'avgCost': PropertySchema(id: 0, name: r'avgCost', type: IsarType.double),
    r'barcode': PropertySchema(id: 1, name: r'barcode', type: IsarType.string),
    r'cachedAt': PropertySchema(
      id: 2,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'categoryName': PropertySchema(
      id: 3,
      name: r'categoryName',
      type: IsarType.string,
    ),
    r'defaultCode': PropertySchema(
      id: 4,
      name: r'defaultCode',
      type: IsarType.string,
    ),
    r'displayName': PropertySchema(
      id: 5,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'freeQty': PropertySchema(id: 6, name: r'freeQty', type: IsarType.double),
    r'imageSmall': PropertySchema(
      id: 7,
      name: r'imageSmall',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 8, name: r'name', type: IsarType.string),
    r'productId': PropertySchema(
      id: 9,
      name: r'productId',
      type: IsarType.long,
    ),
    r'qtyAvailable': PropertySchema(
      id: 10,
      name: r'qtyAvailable',
      type: IsarType.double,
    ),
    r'qtyIncoming': PropertySchema(
      id: 11,
      name: r'qtyIncoming',
      type: IsarType.double,
    ),
    r'qtyOnHand': PropertySchema(
      id: 12,
      name: r'qtyOnHand',
      type: IsarType.double,
    ),
    r'qtyOutgoing': PropertySchema(
      id: 13,
      name: r'qtyOutgoing',
      type: IsarType.double,
    ),
    r'totalValue': PropertySchema(
      id: 14,
      name: r'totalValue',
      type: IsarType.double,
    ),
    r'uomName': PropertySchema(id: 15, name: r'uomName', type: IsarType.string),
  },

  estimateSize: _inventoryProductEntityEstimateSize,
  serialize: _inventoryProductEntitySerialize,
  deserialize: _inventoryProductEntityDeserialize,
  deserializeProp: _inventoryProductEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'productId': IndexSchema(
      id: 5580769080710688203,
      name: r'productId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'productId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _inventoryProductEntityGetId,
  getLinks: _inventoryProductEntityGetLinks,
  attach: _inventoryProductEntityAttach,
  version: '3.3.0',
);

int _inventoryProductEntityEstimateSize(
  InventoryProductEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.barcode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.categoryName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.defaultCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.displayName.length * 3;
  {
    final value = object.imageSmall;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.uomName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _inventoryProductEntitySerialize(
  InventoryProductEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.avgCost);
  writer.writeString(offsets[1], object.barcode);
  writer.writeDateTime(offsets[2], object.cachedAt);
  writer.writeString(offsets[3], object.categoryName);
  writer.writeString(offsets[4], object.defaultCode);
  writer.writeString(offsets[5], object.displayName);
  writer.writeDouble(offsets[6], object.freeQty);
  writer.writeString(offsets[7], object.imageSmall);
  writer.writeString(offsets[8], object.name);
  writer.writeLong(offsets[9], object.productId);
  writer.writeDouble(offsets[10], object.qtyAvailable);
  writer.writeDouble(offsets[11], object.qtyIncoming);
  writer.writeDouble(offsets[12], object.qtyOnHand);
  writer.writeDouble(offsets[13], object.qtyOutgoing);
  writer.writeDouble(offsets[14], object.totalValue);
  writer.writeString(offsets[15], object.uomName);
}

InventoryProductEntity _inventoryProductEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = InventoryProductEntity();
  object.avgCost = reader.readDouble(offsets[0]);
  object.barcode = reader.readStringOrNull(offsets[1]);
  object.cachedAt = reader.readDateTime(offsets[2]);
  object.categoryName = reader.readStringOrNull(offsets[3]);
  object.defaultCode = reader.readStringOrNull(offsets[4]);
  object.displayName = reader.readString(offsets[5]);
  object.freeQty = reader.readDouble(offsets[6]);
  object.id = id;
  object.imageSmall = reader.readStringOrNull(offsets[7]);
  object.name = reader.readString(offsets[8]);
  object.productId = reader.readLong(offsets[9]);
  object.qtyAvailable = reader.readDouble(offsets[10]);
  object.qtyIncoming = reader.readDouble(offsets[11]);
  object.qtyOnHand = reader.readDouble(offsets[12]);
  object.qtyOutgoing = reader.readDouble(offsets[13]);
  object.totalValue = reader.readDouble(offsets[14]);
  object.uomName = reader.readStringOrNull(offsets[15]);
  return object;
}

P _inventoryProductEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readDouble(offset)) as P;
    case 14:
      return (reader.readDouble(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _inventoryProductEntityGetId(InventoryProductEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _inventoryProductEntityGetLinks(
  InventoryProductEntity object,
) {
  return [];
}

void _inventoryProductEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  InventoryProductEntity object,
) {
  object.id = id;
}

extension InventoryProductEntityQueryWhereSort
    on QueryBuilder<InventoryProductEntity, InventoryProductEntity, QWhere> {
  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterWhere>
  anyProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'productId'),
      );
    });
  }
}

extension InventoryProductEntityQueryWhere
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QWhereClause
        > {
  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  productIdEqualTo(int productId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'productId', value: [productId]),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  productIdNotEqualTo(int productId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [],
                upper: [productId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [productId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [productId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [],
                upper: [productId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  productIdGreaterThan(int productId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [productId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  productIdLessThan(int productId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [],
          upper: [productId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterWhereClause
  >
  productIdBetween(
    int lowerProductId,
    int upperProductId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [lowerProductId],
          includeLower: includeLower,
          upper: [upperProductId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension InventoryProductEntityQueryFilter
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QFilterCondition
        > {
  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  avgCostEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'avgCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  avgCostGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'avgCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  avgCostLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'avgCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  avgCostBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'avgCost',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'barcode'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'barcode'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'barcode',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'barcode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'barcode', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  barcodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'barcode', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  cachedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  cachedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  cachedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cachedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryName'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryName'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryName',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'categoryName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'categoryName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryName', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  categoryNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'categoryName', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'defaultCode'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'defaultCode'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultCode',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'defaultCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'defaultCode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultCode', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  defaultCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'defaultCode', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'displayName',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'displayName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  freeQtyEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'freeQty',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  freeQtyGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'freeQty',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  freeQtyLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'freeQty',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  freeQtyBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'freeQty',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imageSmall'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imageSmall'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imageSmall',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imageSmall',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imageSmall',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imageSmall', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  imageSmallIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imageSmall', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  nameEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  nameBetween(
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  nameMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  productIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productId', value: value),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  productIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  productIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  productIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyAvailableEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'qtyAvailable',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyAvailableGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'qtyAvailable',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyAvailableLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'qtyAvailable',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyAvailableBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'qtyAvailable',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyIncomingEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'qtyIncoming',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyIncomingGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'qtyIncoming',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyIncomingLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'qtyIncoming',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyIncomingBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'qtyIncoming',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOnHandEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'qtyOnHand',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOnHandGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'qtyOnHand',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOnHandLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'qtyOnHand',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOnHandBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'qtyOnHand',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOutgoingEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'qtyOutgoing',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOutgoingGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'qtyOutgoing',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOutgoingLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'qtyOutgoing',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  qtyOutgoingBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'qtyOutgoing',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  totalValueEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalValue',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  totalValueGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalValue',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  totalValueLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalValue',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  totalValueBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalValue',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'uomName'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'uomName'),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'uomName',
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
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'uomName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'uomName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uomName', value: ''),
      );
    });
  }

  QueryBuilder<
    InventoryProductEntity,
    InventoryProductEntity,
    QAfterFilterCondition
  >
  uomNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uomName', value: ''),
      );
    });
  }
}

extension InventoryProductEntityQueryObject
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QFilterCondition
        > {}

extension InventoryProductEntityQueryLinks
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QFilterCondition
        > {}

extension InventoryProductEntityQuerySortBy
    on QueryBuilder<InventoryProductEntity, InventoryProductEntity, QSortBy> {
  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByAvgCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgCost', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByAvgCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgCost', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByCategoryName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByCategoryNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryName', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByDefaultCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCode', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByDefaultCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCode', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByFreeQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'freeQty', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByFreeQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'freeQty', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyAvailable', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyAvailable', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyIncoming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyIncoming', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyIncomingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyIncoming', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyOnHand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOnHand', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyOnHandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOnHand', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyOutgoing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOutgoing', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByQtyOutgoingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOutgoing', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByTotalValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalValue', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByTotalValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalValue', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByUomName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uomName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  sortByUomNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uomName', Sort.desc);
    });
  }
}

extension InventoryProductEntityQuerySortThenBy
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QSortThenBy
        > {
  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByAvgCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgCost', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByAvgCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgCost', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByCategoryName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByCategoryNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryName', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByDefaultCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCode', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByDefaultCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCode', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByFreeQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'freeQty', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByFreeQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'freeQty', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyAvailable', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyAvailable', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyIncoming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyIncoming', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyIncomingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyIncoming', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyOnHand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOnHand', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyOnHandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOnHand', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyOutgoing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOutgoing', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByQtyOutgoingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyOutgoing', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByTotalValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalValue', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByTotalValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalValue', Sort.desc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByUomName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uomName', Sort.asc);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QAfterSortBy>
  thenByUomNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uomName', Sort.desc);
    });
  }
}

extension InventoryProductEntityQueryWhereDistinct
    on QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct> {
  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByAvgCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'avgCost');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByBarcode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'barcode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByCategoryName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByDefaultCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByFreeQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'freeQty');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByImageSmall({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageSmall', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productId');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByQtyAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qtyAvailable');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByQtyIncoming() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qtyIncoming');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByQtyOnHand() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qtyOnHand');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByQtyOutgoing() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qtyOutgoing');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByTotalValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalValue');
    });
  }

  QueryBuilder<InventoryProductEntity, InventoryProductEntity, QDistinct>
  distinctByUomName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uomName', caseSensitive: caseSensitive);
    });
  }
}

extension InventoryProductEntityQueryProperty
    on
        QueryBuilder<
          InventoryProductEntity,
          InventoryProductEntity,
          QQueryProperty
        > {
  QueryBuilder<InventoryProductEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  avgCostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avgCost');
    });
  }

  QueryBuilder<InventoryProductEntity, String?, QQueryOperations>
  barcodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'barcode');
    });
  }

  QueryBuilder<InventoryProductEntity, DateTime, QQueryOperations>
  cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<InventoryProductEntity, String?, QQueryOperations>
  categoryNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryName');
    });
  }

  QueryBuilder<InventoryProductEntity, String?, QQueryOperations>
  defaultCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultCode');
    });
  }

  QueryBuilder<InventoryProductEntity, String, QQueryOperations>
  displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  freeQtyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'freeQty');
    });
  }

  QueryBuilder<InventoryProductEntity, String?, QQueryOperations>
  imageSmallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageSmall');
    });
  }

  QueryBuilder<InventoryProductEntity, String, QQueryOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<InventoryProductEntity, int, QQueryOperations>
  productIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productId');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  qtyAvailableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qtyAvailable');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  qtyIncomingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qtyIncoming');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  qtyOnHandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qtyOnHand');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  qtyOutgoingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qtyOutgoing');
    });
  }

  QueryBuilder<InventoryProductEntity, double, QQueryOperations>
  totalValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalValue');
    });
  }

  QueryBuilder<InventoryProductEntity, String?, QQueryOperations>
  uomNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uomName');
    });
  }
}
