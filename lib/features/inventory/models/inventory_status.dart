class InventoryStatus {
  final bool isInstalled;
  final bool hasAccess;
  final String? message;

  const InventoryStatus({required this.isInstalled, required this.hasAccess, this.message});
}
