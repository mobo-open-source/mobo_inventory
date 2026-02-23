/// Model representing an Odoo product product with inventory-specific data.
class InventoryProduct {
  final int id;
  final String name;
  final String displayname;
  final String? defaultCode;
  final String? barcode;
  final double qtyOnHand;
  final double qtyIncoming;
  final double qtyOutgoing;
  final double qtyAvailable;
  final double freeQty;
  final double avgCost;
  final double totalValue;
  final List? uomId;
  final List? categId;
  final String? imageSmall;

  InventoryProduct({
    required this.id,
    required this.name,
    required this.displayname,
    this.defaultCode,
    this.barcode,
    required this.qtyOnHand,
    required this.qtyIncoming,
    required this.qtyOutgoing,
    required this.qtyAvailable,
    required this.freeQty,
    required this.avgCost,
    required this.totalValue,
    this.uomId,
    this.categId,
    this.imageSmall,
  });

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    String? safeString(dynamic value) {
      if (value == null || value == false) return null;
      return value.toString();
    }

    List<dynamic>? parseM2O(dynamic value) {
      if (value == null || value == false) return null;
      if (value is List) return value;
      if (value is Map) {
        final id = value['id'];
        final name = value['display_name'] ?? value['name'];
        return [id, if (name != null) name.toString()];
      }
      return null;
    }

    String resolveDisplayName(Map<String, dynamic> j) {
      final raw = j.containsKey('display_name')
          ? j['display_name']
          : (j.containsKey('displayname') ? j['displayname'] : j['name']);

      if (raw == null || raw == false) return '';
      if (raw is List && raw.length > 1) return raw[1]?.toString() ?? '';
      if (raw is Map) {
        final dn = raw['display_name'] ?? raw['name'];
        return dn?.toString() ?? '';
      }
      return raw.toString();
    }

    double asDouble(dynamic v) {
      if (v == null || v == false) return 0.0;
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s) ?? 0.0;
    }

    final qtyAvailableOnHand = asDouble(json['qty_available']);
    final stdPrice = asDouble(json['standard_price'] ?? json['avg_cost']);
    final computedTotalValue = asDouble(
      json['total_value'] ?? (qtyAvailableOnHand * stdPrice),
    );

    return InventoryProduct(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: safeString(json['name']) ?? '',
      displayname: resolveDisplayName(json),
      defaultCode: safeString(json['default_code']),
      barcode: safeString(json['barcode']),
      qtyOnHand: qtyAvailableOnHand,
      qtyIncoming: asDouble(json['incoming_qty']),
      qtyOutgoing: asDouble(json['outgoing_qty']),
      qtyAvailable: asDouble(
        json['virtual_available'] ?? json['qty_available'],
      ),
      freeQty: asDouble(json['free_qty']),
      avgCost: stdPrice,
      totalValue: computedTotalValue,
      uomId: parseM2O(json['uom_id']),
      categId: parseM2O(json['categ_id']),
      imageSmall: safeString(json['image_128']),
    );
  }

  String get categoryName =>
      categId != null && categId!.length > 1 ? categId![1].toString() : '';

  String get uomName =>
      uomId != null && uomId!.length > 1 ? uomId![1].toString() : 'Units';
}
