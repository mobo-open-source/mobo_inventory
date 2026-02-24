import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/haptics_service.dart';

class ProductSelectorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String title;

  const ProductSelectorDialog({
    super.key,
    required this.products,
    this.title = 'Select Product',
  });

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final filteredProducts = widget.products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final code = p['default_code']?.toString().toLowerCase() ?? '';
      final barcode = p['barcode']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          barcode.contains(query);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF232323) : Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  HugeIcons.strokeRoundedPackage,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _searchController,
              autofocus: true,
              onTapOutside: (val) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Search by name, code, or barcode...',
                prefixIcon: Icon(
                  HugeIcons.strokeRoundedSearch01,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                HapticsService.light();
              },
            ),
            const SizedBox(height: 16),

            if (filteredProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(
                      '${filteredProducts.length} ${filteredProducts.length == 1 ? 'product' : 'products'}',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.products.isEmpty
                                ? HugeIcons.strokeRoundedPackageOpen
                                : HugeIcons.strokeRoundedSearch01,
                            size: 64,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.products.isEmpty
                                ? 'No products available'
                                : 'No products match your search',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (ctx, index) {
                        final product = filteredProducts[index];
                        final productName =
                            product['name']?.toString() ?? 'Unknown';
                        final defaultCode = product['default_code']?.toString();
                        final barcode = product['barcode']?.toString();
                        final qtyAvailable = product['qty_available'] ?? 0;
                        final uomName = product['uom_id'] is List
                            ? (product['uom_id'] as List)[1]?.toString() ??
                                  'Unit'
                            : 'Unit';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              HapticsService.selection();
                              Navigator.pop(context, product);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          productName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: qtyAvailable > 0
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '$qtyAvailable $uomName',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: qtyAvailable > 0
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (defaultCode != null ||
                                      barcode != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (defaultCode != null) ...[
                                          Icon(
                                            HugeIcons.strokeRoundedTag01,
                                            size: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            defaultCode,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        if (defaultCode != null &&
                                            barcode != null)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              '•',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey[600]
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                        if (barcode != null) ...[
                                          Icon(
                                            Icons.qr_code_2,
                                            size: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            barcode,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
