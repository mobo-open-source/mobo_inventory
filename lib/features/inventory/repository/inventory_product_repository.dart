import 'package:isar_community/isar.dart';
import '../../../core/services/isar_service.dart';
import '../models/inventory_product.dart';
import '../models/inventory_product_isar.dart';

/// Repository for managing the local persistent cache of inventory products using Isar.
class InventoryProductRepository {
  Future<Isar> get _db async => await IsarService.instance;

  /// Replaces the current cache with the provided list of products.
  Future<void> replaceCache(List<InventoryProduct> products) async {
    final db = await _db;
    final now = DateTime.now();
    final entities = products.map(_mapToEntity).toList(growable: false);
    for (final e in entities) {
      e.cachedAt = now;
    }

    await db.writeTxn(() async {
      await db.inventoryProductEntitys.clear();
      await db.inventoryProductEntitys.putAll(entities);
    });
  }

  Future<List<InventoryProduct>> getAllCached() async {
    final db = await _db;
    final entities = await db.inventoryProductEntitys
        .where()
        .sortByCachedAtDesc()
        .findAll();
    return entities.map(_mapFromEntity).toList(growable: false);
  }

  InventoryProductEntity _mapToEntity(InventoryProduct p) {
    final e = InventoryProductEntity()
      ..productId = p.id
      ..name = p.name
      ..displayName = p.displayname
      ..defaultCode = p.defaultCode
      ..barcode = p.barcode
      ..qtyOnHand = p.qtyOnHand
      ..qtyIncoming = p.qtyIncoming
      ..qtyOutgoing = p.qtyOutgoing
      ..qtyAvailable = p.qtyAvailable
      ..freeQty = p.freeQty
      ..avgCost = p.avgCost
      ..totalValue = p.totalValue
      ..uomName = p.uomName
      ..categoryName = p.categoryName
      ..imageSmall = p.imageSmall;

    e.id = p.id;
    return e;
  }

  InventoryProduct _mapFromEntity(InventoryProductEntity e) {
    return InventoryProduct(
      id: e.productId,
      name: e.name,
      displayname: e.displayName,
      defaultCode: e.defaultCode,
      barcode: e.barcode,
      qtyOnHand: e.qtyOnHand,
      qtyIncoming: e.qtyIncoming,
      qtyOutgoing: e.qtyOutgoing,
      qtyAvailable: e.qtyAvailable,
      freeQty: e.freeQty,
      avgCost: e.avgCost,
      totalValue: e.totalValue,
      uomId: [null, e.uomName ?? 'Units'],
      categId: [null, e.categoryName ?? ''],
      imageSmall: e.imageSmall,
    );
  }
}
