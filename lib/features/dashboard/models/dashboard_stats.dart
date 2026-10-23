/// Model representing high-level dashboard metrics.
class DashboardStats {
  final int totalWarehouses;
  final int totalLocations;
  final int deliveryOrders;
  final int readyToDeliver;
  final int receipts;
  final int readyToReceive;
  final int internalTransfers;
  final int readyToTransfer;

  /// Point of Sale pickings to process — Odoo's PoS Orders card, kept out of
  /// [deliveryOrders].
  final int posOrders;

  final int manufacturingOrders;
  final int readyToProduce;
  final int negativeQuants;

  /// False when the user may not read warehouses.
  final bool showWarehouses;

  /// False when Odoo's "Storage Locations" setting is off for this user —
  /// Odoo then hides its Locations menu, so the dashboard hides it too — or
  /// the user may not read locations.
  final bool showLocations;

  /// False when the user may not read transfers (`stock.picking`), so the
  /// Receipts, Delivery Orders and Internal Transfers cards are hidden.
  final bool showPickings;

  /// False when the `mrp` (Manufacturing) module isn't installed, or the
  /// user may not read its orders, so the dashboard hides its Manufacturing
  /// Orders card instead of showing a 0 that means nothing.
  final bool showManufacturing;

  /// False without Point of Sale's stock integration (no PoS operation
  /// type), so the PoS Orders card is hidden.
  final bool showPosOrders;

  DashboardStats({
    required this.totalWarehouses,
    required this.totalLocations,
    required this.deliveryOrders,
    required this.readyToDeliver,
    required this.receipts,
    required this.readyToReceive,
    required this.internalTransfers,
    required this.readyToTransfer,
    required this.manufacturingOrders,
    required this.readyToProduce,
    required this.negativeQuants,
    this.posOrders = 0,
    this.showWarehouses = true,
    this.showLocations = true,
    this.showPickings = true,
    this.showManufacturing = true,
    this.showPosOrders = false,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalWarehouses: 0,
      totalLocations: 0,
      deliveryOrders: 0,
      readyToDeliver: 0,
      receipts: 0,
      readyToReceive: 0,
      internalTransfers: 0,
      readyToTransfer: 0,
      manufacturingOrders: 0,
      readyToProduce: 0,
      negativeQuants: 0,
    );
  }
}
