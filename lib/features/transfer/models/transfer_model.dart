/// Represents an internal stock transfer (picking) in Odoo.
class InternalTransfer {
  final int? id;
  final String name;
  final int? pickingTypeId;
  final String? pickingTypeName;
  final int? locationId;
  final String? locationName;
  final int? locationDestId;
  final String? locationDestName;
  final String? scheduledDate;
  final String state;
  final List<TransferLine> moveLines;

  InternalTransfer({
    this.id,
    required this.name,
    this.pickingTypeId,
    this.pickingTypeName,
    this.locationId,
    this.locationName,
    this.locationDestId,
    this.locationDestName,
    this.scheduledDate,
    this.state = 'draft',
    this.moveLines = const [],
  });

  factory InternalTransfer.fromJson(Map<String, dynamic> json) {
    return InternalTransfer(
      id: json['id'] as int?,
      name: json['name']?.toString() ?? '',
      pickingTypeId: json['picking_type_id'] is List
          ? (json['picking_type_id'] as List)[0] as int?
          : json['picking_type_id'] as int?,
      pickingTypeName:
          json['picking_type_id'] is List &&
              (json['picking_type_id'] as List).length > 1
          ? (json['picking_type_id'] as List)[1].toString()
          : null,
      locationId: json['location_id'] is List
          ? (json['location_id'] as List)[0] as int?
          : json['location_id'] as int?,
      locationName:
          json['location_id'] is List &&
              (json['location_id'] as List).length > 1
          ? (json['location_id'] as List)[1].toString()
          : null,
      locationDestId: json['location_dest_id'] is List
          ? (json['location_dest_id'] as List)[0] as int?
          : json['location_dest_id'] as int?,
      locationDestName:
          json['location_dest_id'] is List &&
              (json['location_dest_id'] as List).length > 1
          ? (json['location_dest_id'] as List)[1].toString()
          : null,
      scheduledDate: json['scheduled_date']?.toString(),
      state: json['state']?.toString() ?? 'draft',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (pickingTypeId != null) 'picking_type_id': pickingTypeId,
      if (locationId != null) 'location_id': locationId,
      if (locationDestId != null) 'location_dest_id': locationDestId,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      'state': state,
    };
  }

  InternalTransfer copyWith({
    int? id,
    String? name,
    int? pickingTypeId,
    String? pickingTypeName,
    int? locationId,
    String? locationName,
    int? locationDestId,
    String? locationDestName,
    String? scheduledDate,
    String? state,
    List<TransferLine>? moveLines,
  }) {
    return InternalTransfer(
      id: id ?? this.id,
      name: name ?? this.name,
      pickingTypeId: pickingTypeId ?? this.pickingTypeId,
      pickingTypeName: pickingTypeName ?? this.pickingTypeName,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      locationDestId: locationDestId ?? this.locationDestId,
      locationDestName: locationDestName ?? this.locationDestName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      state: state ?? this.state,
      moveLines: moveLines ?? this.moveLines,
    );
  }
}

/// Represents a single line item within an [InternalTransfer].
class TransferLine {
  final int? id;
  final int? productId;
  final String? productName;
  final double quantity;
  final String? productUom;
  final double unitPrice;

  TransferLine({
    this.id,
    this.productId,
    this.productName,
    required this.quantity,
    this.productUom,
    this.unitPrice = 0.0,
  });

  factory TransferLine.fromJson(Map<String, dynamic> json) {
    return TransferLine(
      id: json['id'] as int?,
      productId: json['product_id'] is List
          ? (json['product_id'] as List)[0] as int?
          : json['product_id'] as int?,
      productName:
          json['product_id'] is List && (json['product_id'] as List).length > 1
          ? (json['product_id'] as List)[1].toString()
          : null,
      quantity: (json['product_uom_qty'] ?? json['quantity'] ?? 0).toDouble(),
      productUom: json['product_uom']?.toString(),
      unitPrice: (json['price_unit'] ?? json['unit_price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      'product_uom_qty': quantity,
      if (productUom != null) 'product_uom': productUom,
      'price_unit': unitPrice,
    };
  }
}
