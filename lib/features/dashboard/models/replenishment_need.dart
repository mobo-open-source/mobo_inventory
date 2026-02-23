/// Model representing a product that needs replenishment based on orderpoints.
class ReplenishmentNeed {
  final int productId;
  final String productName;
  final double minQty;
  final double maxQty;
  final double onHand;

  ReplenishmentNeed({
    required this.productId,
    required this.productName,
    required this.minQty,
    required this.maxQty,
    required this.onHand,
  });

  double get shortage => (minQty - onHand);
}
