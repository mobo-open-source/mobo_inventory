class ManufacturingTransfer {
  final int id;
  final String name;
  final String state;
  final String? origin;
  final String? productName;
  final double? productQty;
  final String? uomName;
  final String? scheduledDate;

  ManufacturingTransfer({
    required this.id,
    required this.name,
    required this.state,
    this.origin,
    this.productName,
    this.productQty,
    this.uomName,
    this.scheduledDate,
  });

  factory ManufacturingTransfer.fromJson(Map<String, dynamic> json) {
    String? prodName;
    final prod = json['product_id'];
    if (prod is List && prod.length > 1) {
      prodName = prod[1]?.toString();
    }
    if (prod is Map) {
      prodName = (prod['display_name'] ?? prod['name'])?.toString();
    }

    String? uomName;
    final uom = json['product_uom_id'];
    if (uom is List && uom.length > 1) uomName = uom[1]?.toString();
    if (uom is Map) uomName = (uom['display_name'] ?? uom['name'])?.toString();

    return ManufacturingTransfer(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      productName: prodName,
      productQty: (json['product_qty'] ?? json['qty_produced'])?.toDouble(),
      uomName: uomName,
      scheduledDate:
          (json['date_planned_start'] ??
                  json['scheduled_date'] ??
                  json['date_start'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'origin': origin,
      'product_id': productName != null ? [0, productName] : null,
      'product_qty': productQty,
      'product_uom_id': uomName != null ? [0, uomName] : null,
      'date_start': scheduledDate,
    };
  }
}
