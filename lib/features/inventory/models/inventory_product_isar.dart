import 'package:isar_community/isar.dart';
part 'inventory_product_isar.g.dart';

@collection
class InventoryProductEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late int productId;

  late String name;
  late String displayName;
  String? defaultCode;
  String? barcode;

  double qtyOnHand = 0;
  double qtyIncoming = 0;
  double qtyOutgoing = 0;
  double qtyAvailable = 0;
  double freeQty = 0;
  double avgCost = 0;
  double totalValue = 0;

  String? uomName;
  String? categoryName;

  String? imageSmall;

  DateTime cachedAt = DateTime.now();
}
