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
  final int manufacturingOrders;
  final int readyToProduce;
  final int negativeQuants;

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
