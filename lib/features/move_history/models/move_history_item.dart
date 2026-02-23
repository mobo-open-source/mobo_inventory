
class MoveHistoryItem {
  final int id;
  final DateTime? date;
  final String? reference;
  final String? product;
  final int? productId;
  final String? lotSerial;
  final String? fromLocation;
  final String? toLocation;
  final int? fromLocationId;
  final int? toLocationId;
  final double quantity;
  final String? status;
  final String? productCategory;
  final String? transfer;

  MoveHistoryItem({
    required this.id,
    this.date,
    this.reference,
    this.product,
    this.productId,
    this.lotSerial,
    this.fromLocation,
    this.toLocation,
    required this.quantity,
    this.status,
    this.fromLocationId,
    this.toLocationId,
    this.productCategory,
    this.transfer,
  });

  factory MoveHistoryItem.fromJson(Map<String, dynamic> json) {

    int? productId;
    String? productName;
    final p = json['product_id'];
    if (p is Map<String, dynamic>) {
      productId = p['id'] as int?;
      productName = p['display_name'] as String?;
    } else if (p is List && p.isNotEmpty) {
      productId = p[0] as int?;
      productName = p.length > 1 ? p[1].toString() : null;
    } else if (p is int) {
      productId = p;
    }

    String? lot;
    final l = json['lot_id'];
    if (l is Map<String, dynamic>) {
      lot = l['display_name'] as String?;
    } else if (l is List && l.isNotEmpty) {
      lot = l.length > 1 ? l[1].toString() : null;
    }

    String? fromLoc;
    int? fromLocId;
    final fl = json['location_id'];
    if (fl is Map<String, dynamic>) {
      fromLoc = fl['display_name'] as String?;
      fromLocId = fl['id'] as int?;
    } else if (fl is List && fl.isNotEmpty) {
      fromLocId = fl[0] as int?;
      fromLoc = fl.length > 1 ? fl[1].toString() : null;
    }

    String? toLoc;
    int? toLocId;
    final tl = json['location_dest_id'];
    if (tl is Map<String, dynamic>) {
      toLoc = tl['display_name'] as String?;
      toLocId = tl['id'] as int?;
    } else if (tl is List && tl.isNotEmpty) {
      toLocId = tl[0] as int?;
      toLoc = tl.length > 1 ? tl[1].toString() : null;
    }

    String? reference;
    final mv = json['move_id'];
    if (mv is Map<String, dynamic>) {
      reference = mv['name']?.toString() ?? mv['display_name']?.toString();
    } else if (mv is List && mv.isNotEmpty) {
      reference = mv.length > 1 ? mv[1].toString() : null;
    } else if (json['reference'] != null) {
      reference = json['reference'].toString();
    }

    String? transfer;
    final pk = json['picking_id'];
    if (pk is Map<String, dynamic>) {
      transfer = pk['display_name']?.toString();
    } else if (pk is List && pk.isNotEmpty) {
      transfer = pk.length > 1 ? pk[1].toString() : null;
    }

    DateTime? date;
    final d = json['date']?.toString();
    if (d != null) {
      date = DateTime.tryParse(d);
    }

    final qty = (json['quantity'] ?? json['qty_done'] ?? json['quantity_done'] ?? json['product_uom_qty'] ?? 0) as num;

    return MoveHistoryItem(
      id: json['id'] as int,
      date: date,
      reference: reference,
      product: productName,
      productId: productId,
      lotSerial: lot,
      fromLocation: fromLoc,
      fromLocationId: fromLocId,
      toLocation: toLoc,
      toLocationId: toLocId,
      quantity: qty.toDouble(),
      status: json['state']?.toString(),
      transfer: transfer,
    );
  }

  MoveHistoryItem copyWith({
    DateTime? date,
    String? reference,
    String? product,
    int? productId,
    String? lotSerial,
    String? fromLocation,
    String? toLocation,
    int? fromLocationId,
    int? toLocationId,
    double? quantity,
    String? status,
    String? productCategory,
    String? transfer,
  }) {
    return MoveHistoryItem(
      id: id,
      date: date ?? this.date,
      reference: reference ?? this.reference,
      product: product ?? this.product,
      productId: productId ?? this.productId,
      lotSerial: lotSerial ?? this.lotSerial,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      fromLocationId: fromLocationId ?? this.fromLocationId,
      toLocationId: toLocationId ?? this.toLocationId,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      productCategory: productCategory ?? this.productCategory,
      transfer: transfer ?? this.transfer,
    );
  }
}
