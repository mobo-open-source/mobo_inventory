/// Model representing a product that needs replenishment based on orderpoints.
class ReplenishmentNeed {
  final int productId;
  final String productName;
  final String locationName;
  final double minQty;
  final double maxQty;
  final double onHand;

  /// On hand plus incoming minus outgoing at the orderpoint's location —
  /// what Odoo compares with [minQty] to decide whether to reorder.
  final double forecast;

  /// What Odoo's Replenishment screen proposes ordering ("To Order").
  final double toOrder;

  ReplenishmentNeed({
    required this.productId,
    required this.productName,
    this.locationName = '',
    required this.minQty,
    required this.maxQty,
    required this.onHand,
    required this.forecast,
    required this.toOrder,
  });

  /// Reads a `stock.warehouse.orderpoint` row; null when it has no product.
  static ReplenishmentNeed? fromOrderpoint(Map<String, dynamic> row) {
    final product = row['product_id'];
    if (product is! List || product.length < 2) return null;
    final location = row['location_id'];
    double qty(String field) => (row[field] as num?)?.toDouble() ?? 0.0;

    return ReplenishmentNeed(
      productId: (product[0] as num).toInt(),
      productName: product[1].toString(),
      locationName: location is List && location.length > 1
          ? location[1].toString()
          : '',
      minQty: qty('product_min_qty'),
      maxQty: qty('product_max_qty'),
      onHand: qty('qty_on_hand'),
      forecast: qty('qty_forecast'),
      toOrder: qty('qty_to_order'),
    );
  }
}
