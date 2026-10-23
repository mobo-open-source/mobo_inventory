import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../services/product_search_service.dart';
import '../../../core/utils/base64_utils.dart';

/// Inline, always-on-screen product search field with a live suggestions
/// overlay — the search-as-you-type replacement for the old full-screen
/// "select a product" bottom sheet.
///
/// Typing filters the catalog live; tapping a suggestion adds it immediately
/// (quantity defaults to 1, editable afterwards in the line list) via
/// [onProductAdded], then clears itself so it's ready for the next product.
class MoboProductSearchField extends StatefulWidget {
  final bool isDark;
  final String label;
  final String hintText;
  final ValueChanged<Map<String, dynamic>> onProductAdded;

  const MoboProductSearchField({
    super.key,
    required this.isDark,
    required this.onProductAdded,
    this.label = 'Search Product to Add',
    this.hintText = 'Search products...',
  });

  @override
  State<MoboProductSearchField> createState() =>
      _MoboProductSearchFieldState();
}

class _MoboProductSearchFieldState extends State<MoboProductSearchField> {
  final ProductSearchService _service = ProductSearchService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  bool _hasFocus = false;

  /// Height kept under the field while it is focused: room for the
  /// suggestions box, and scroll extent so the field can reach the top even
  /// when it sits near the end of the form.
  static const double _suggestionsHeight = 260;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // The suggestions used to flip above the field once the keyboard was up,
  // and the overlay then ran over the app bar. Instead the field scrolls to
  // the top of the screen so the box always opens below it.
  void _onFocusChanged() {
    if (_hasFocus == _focusNode.hasFocus) return;
    setState(() => _hasFocus = _focusNode.hasFocus);
    if (!_hasFocus) return;
    // Wait for the keyboard to finish opening so the viewport has its final
    // size before scrolling.
    Future.delayed(const Duration(milliseconds: 350), () {
      final ctx = _fieldKey.currentContext;
      if (!mounted || !_focusNode.hasFocus || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<List<Map<String, dynamic>>> _search(String query) {
    final trimmed = query.trim();
    return _service.fetchProducts(
      searchQuery: trimmed.isEmpty ? null : trimmed,
      limit: 20,
    );
  }

  void _onSelected(Map<String, dynamic> product) {
    widget.onProductAdded({
      'product': product,
      'quantity': 1.0,
      'unit_price': (product['list_price'] as num?)?.toDouble() ?? 0.0,
    });
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? Colors.grey[850]! : AppTheme.inputFill;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final popupBg = isDark ? AppTheme.darkPopupSurface : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: _fieldKey,
          widget.label,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        TypeAheadField<Map<String, dynamic>>(
          controller: _controller,
          focusNode: _focusNode,
          debounceDuration: const Duration(milliseconds: 400),
          suggestionsCallback: _search,
          onSelected: _onSelected,
          // Always below the field; it shrinks to the space left above the
          // keyboard on short screens rather than covering the app bar.
          constraints: const BoxConstraints(maxHeight: _suggestionsHeight),
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: bgColor,
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  HugeIcons.strokeRoundedPackage,
                  size: 20,
                  color: iconColor,
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: iconColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            );
          },
          decorationBuilder: (context, child) {
            return Material(
              type: MaterialType.card,
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              color: popupBg,
              child: child,
            );
          },
          itemBuilder: (context, product) => _ProductSuggestionTile(
            product: product,
            isDark: isDark,
          ),
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Text(
              'No products found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
          errorBuilder: (context, error) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Text(
              'Failed to search products',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ),
        if (_hasFocus) const SizedBox(height: _suggestionsHeight),
      ],
    );
  }
}

class _ProductSuggestionTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isDark;

  const _ProductSuggestionTile({required this.product, required this.isDark});

  Uint8List? _decodeImage(String? imageData) {
    if (imageData == null || imageData.isEmpty || imageData == 'false') {
      return null;
    }
    try {
      final base64String =
          imageData.contains(',') ? imageData.split(',').last : imageData;
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Unknown';
    final defaultCode = product['default_code']?.toString();
    final hasCode = defaultCode != null && defaultCode.toLowerCase() != 'false';
    final qty = product['qty_available'];
    final qtyText = qty == null ? '-' : (qty as num).toStringAsFixed(0);
    final price = (product['list_price'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final imageBytes = _decodeImage(odooBinaryToBase64(product['image_128']));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        HugeIcons.strokeRoundedPackage,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 22,
                      ),
                    )
                  : Icon(
                      HugeIcons.strokeRoundedPackage,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stock: $qtyText',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (hasCode)
                      Expanded(
                        child: Text(
                          'SKU: $defaultCode',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      'Price: $price',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
