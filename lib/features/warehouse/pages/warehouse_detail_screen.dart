import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_detail_provider.dart';

/// A screen displaying the comprehensive profile and configuration of a warehouse.
///
/// Shows key details such as short name, company association, and physical address.
class WarehouseDetailScreen extends StatefulWidget {
  final int warehouseId;
  const WarehouseDetailScreen({super.key, required this.warehouseId});

  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen> {
  Future<void> _load() async {
    await context.read<WarehouseDetailProvider>().load(widget.warehouseId);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        title: Text(
          'Warehouse Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Consumer<WarehouseDetailProvider>(
          builder: (_, provider, __) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            final name = provider.name;
            final code = provider.code;
            final company = provider.companyName;
            final address = provider.partnerName;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (provider.isOffline)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.tertiary.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 18,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline – showing cached data',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildInfoCard(
                    isDark,
                    children: [
                      Text(
                        'Warehouse Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Name',
                        name.isEmpty ? '-' : name,
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        'Short Name',
                        code.isEmpty ? '-' : code,
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    isDark,
                    children: [
                      Text(
                        'Company & Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Company',
                        company.isEmpty ? '-' : company,
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        'Address',
                        address.isEmpty ? '-' : address,
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow('Opening Hours', '-', isDark),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
