/// Model representing a product with negative quantity in a specific location.
class NegativeQuant {
  final int id;
  final String productName;
  final String locationName;
  final double quantity;

  NegativeQuant({
    required this.id,
    required this.productName,
    required this.locationName,
    required this.quantity,
  });

  factory NegativeQuant.fromMap(Map<String, dynamic> data) {
    final prod = data['product_id'];
    final loc = data['location_id'];
    String nameFromRel(dynamic rel) {
      if (rel is List && rel.length >= 2) return rel[1].toString();
      return (rel ?? '').toString();
    }

    return NegativeQuant(
      id: (data['id'] as int),
      productName: nameFromRel(prod),
      locationName: nameFromRel(loc),
      quantity: ((data['quantity'] ?? 0) as num).toDouble(),
    );
  }
}
