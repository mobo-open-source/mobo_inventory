/// Represents an inventory adjustment record in Odoo (`stock.quant`).
class InventoryAdjustment {
  final int? id;
  final String? productName;
  final int? productId;
  final String? location;
  final int? locationId;
  final String? lotSerial;
  final double onHandQuantity;
  final double countedQuantity;
  final double difference;
  final String? scheduledDate;
  final String? user;

  InventoryAdjustment({
    this.id,
    this.productName,
    this.productId,
    this.location,
    this.locationId,
    this.lotSerial,
    required this.onHandQuantity,
    required this.countedQuantity,
    required this.difference,
    this.scheduledDate,
    this.user,
  });

  factory InventoryAdjustment.fromJson(Map<String, dynamic> json) {
    int? productId;
    String? productName;

    if (json['product_id'] is Map) {
      final productMap = json['product_id'] as Map<String, dynamic>;
      productId = productMap['id'] as int?;
      productName = productMap['display_name'] as String?;
    } else if (json['product_id'] is List) {
      final productList = json['product_id'] as List;
      productId = productList.isNotEmpty ? productList[0] as int? : null;
      productName = productList.length > 1 ? productList[1].toString() : null;
    } else if (json['product_id'] is int) {
      productId = json['product_id'] as int?;
    }

    int? locationId;
    String? location;

    if (json['location_id'] is Map) {
      final locationMap = json['location_id'] as Map<String, dynamic>;
      locationId = locationMap['id'] as int?;
      location = locationMap['display_name'] as String?;
    } else if (json['location_id'] is List) {
      final locationList = json['location_id'] as List;
      locationId = locationList.isNotEmpty ? locationList[0] as int? : null;
      location = locationList.length > 1 ? locationList[1].toString() : null;
    } else if (json['location_id'] is int) {
      locationId = json['location_id'] as int?;
    }

    String? lotSerial;

    if (json['lot_id'] is Map) {
      final lotMap = json['lot_id'] as Map<String, dynamic>;
      lotSerial = lotMap['display_name'] as String?;
    } else if (json['lot_id'] is List) {
      final lotList = json['lot_id'] as List;
      lotSerial = lotList.length > 1 ? lotList[1].toString() : null;
    }

    String? user;

    if (json['user_id'] is Map) {
      final userMap = json['user_id'] as Map<String, dynamic>;
      user = userMap['display_name'] as String?;
    } else if (json['user_id'] is List) {
      final userList = json['user_id'] as List;
      user = userList.length > 1 ? userList[1].toString() : null;
    }

    final onHand = (json['available_quantity'] ?? json['quantity'] ?? 0)
        .toDouble();

    final invSet = json['inventory_quantity_set'] == true;
    final counted = invSet && json['inventory_quantity'] is num
        ? (json['inventory_quantity'] as num).toDouble()
        : onHand;

    return InventoryAdjustment(
      id: json['id'] as int?,
      productId: productId,
      productName: productName,
      locationId: locationId,
      location: location,
      lotSerial: lotSerial,
      onHandQuantity: onHand,
      countedQuantity: counted,
      difference: counted - onHand,
      scheduledDate: json['inventory_date']?.toString(),
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (locationId != null) 'location_id': locationId,
      'quantity': onHandQuantity,
      'inventory_quantity': countedQuantity,
      'inventory_quantity_set': true,
      if (scheduledDate != null) 'inventory_date': scheduledDate,
    };
  }

  InventoryAdjustment copyWith({
    int? id,
    String? productName,
    int? productId,
    String? location,
    int? locationId,
    String? lotSerial,
    double? onHandQuantity,
    double? countedQuantity,
    double? difference,
    String? scheduledDate,
    String? user,
  }) {
    return InventoryAdjustment(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      productId: productId ?? this.productId,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      lotSerial: lotSerial ?? this.lotSerial,
      onHandQuantity: onHandQuantity ?? this.onHandQuantity,
      countedQuantity: countedQuantity ?? this.countedQuantity,
      difference: difference ?? this.difference,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      user: user ?? this.user,
    );
  }
}
