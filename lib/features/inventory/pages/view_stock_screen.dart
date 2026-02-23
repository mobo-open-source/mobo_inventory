import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/stock_location_provider.dart';
import '../widgets/location_header_row.dart';
import '../widgets/location_tile.dart';
import '../widgets/location_totals_row.dart';
import '../../../shared/widgets/empty_state.dart';

/// Screen displaying the stock breakdown across different locations for a specific product.
class ViewStockScreen extends StatefulWidget {
  final int productId;
  final String productName;
  const ViewStockScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ViewStockScreen> createState() => _ViewStockScreenState();
}

class _ViewStockScreenState extends State<ViewStockScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<StockLocationProvider>();
      vm.loadForProduct(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        title: const Text('Location'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Consumer<StockLocationProvider>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.error != null) {
            return EmptyState(
              title: 'Server Error',
              subtitle: vm.error,
              lottieAsset: 'assets/lotties/Error 404.json',
              actionLabel: 'Retry',
              onAction: () => vm.loadForProduct(widget.productId),
            );
          }
          if (vm.quants.isEmpty) {
            return const EmptyState(
              title: 'No Stock Found',
              subtitle:
                  'There is no stock available for this product in any location.',
              lottieAsset: 'assets/lotties/empty ghost.json',
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LocationHeaderRow(isDark: isDark),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: vm.quants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final q = vm.quants[index];
                      return LocationTile(
                        isDark: isDark,
                        locationName: _m2oName(q['location_id']),
                        productName: _m2oName(q['product_id']).isNotEmpty
                            ? _m2oName(q['product_id'])
                            : widget.productName,
                        onHandQty: _toDouble(
                          q['available_quantity'] ?? q['quantity'],
                        ),
                        reservedQty: _toDouble(q['reserved_quantity']),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                LocationTotalsRow(
                  isDark: isDark,
                  totalOnHand: vm.totalOnHand,
                  totalReserved: vm.totalReserved,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _m2oName(dynamic value) {
    if (value is List && value.length >= 2) return value[1]?.toString() ?? '';
    return '';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class CellText extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool bold;
  const CellText(this.text, {required this.isDark, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}
