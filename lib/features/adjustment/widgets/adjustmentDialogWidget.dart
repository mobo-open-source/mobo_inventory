import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_adjustment_model.dart';
import '../providers/adjustment_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/loaders/loading_indicator.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../core/services/haptics_service.dart';

/// A dialog for entering and updating the counted quantity for an inventory adjustment.
class AdjustmentDialog extends StatefulWidget {
  final InventoryAdjustment adjustment;

  const AdjustmentDialog({super.key, required this.adjustment});

  @override
  State<AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<AdjustmentDialog> {
  late TextEditingController _quantityController;
  bool _isLoading = false;
  double _difference = 0.0;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.adjustment.countedQuantity.toStringAsFixed(2),
    );
    _quantityController.addListener(_calculateDifference);
    _calculateDifference();
  }

  void _calculateDifference() {
    final countedQty = double.tryParse(_quantityController.text) ?? 0.0;
    setState(() {
      _difference = countedQty - widget.adjustment.onHandQuantity;
    });
  }

  @override
  void dispose() {
    _quantityController.removeListener(_calculateDifference);
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _applyAdjustment() async {
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null) {
      CustomSnackbar.showError(context, 'Please enter a valid quantity');
      return;
    }

    if (quantity == widget.adjustment.onHandQuantity) {
      CustomSnackbar.showError(context, 'No changes to apply');
      return;
    }

    if (quantity == 0) {
      final confirm = await CommonDialog.confirm(
        context,
        title: 'Set Count to Zero?',
        message:
            'You are about to set the counted quantity to 0. This will adjust stock to zero for this quant. Do you want to continue?',
        confirmText: 'Yes, Apply',
        cancelText: 'Cancel',
        destructive: true,
      );
      if (confirm != true) {
        return;
      }
    }

    setState(() => _isLoading = true);

    final provider = context.read<AdjustmentProvider>();

    final updateSuccess = await provider.updateCountedQuantity(
      quantId: widget.adjustment.id!,
      countedQuantity: quantity,
    );

    if (!updateSuccess) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(
          context,
          provider.error ?? 'Failed to update quantity',
        );
        HapticsService.error();
      }
      return;
    }

    final applySuccess = await provider.applyAdjustment(widget.adjustment.id!);

    if (mounted) {
      setState(() => _isLoading = false);
      if (applySuccess) {
        Navigator.pop(context);
        CustomSnackbar.showSuccess(
          context,
          'Inventory adjustment applied successfully',
        );
        HapticsService.success();
        provider.refresh();
      } else {
        CustomSnackbar.showError(
          context,
          provider.error ?? 'Failed to apply adjustment',
        );
        HapticsService.error();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Dialog(
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Inventory',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.adjustment.productName ?? 'Unknown Product',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.adjustment.location ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'On Hand',
                      widget.adjustment.onHandQuantity.toStringAsFixed(2),
                      isDark ? Colors.blue[300]! : Colors.blue[700]!,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Difference',
                      '${_difference >= 0 ? '+' : ''}${_difference.toStringAsFixed(2)}',
                      _difference > 0
                          ? (isDark ? Colors.green[300]! : Colors.green[700]!)
                          : _difference < 0
                          ? (isDark ? Colors.red[300]! : Colors.red[700]!)
                          : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Counted Quantity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.primaryColor,
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _applyAdjustment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SmallLoadingIndicator(color: Colors.white)
                          : const Text(
                              'Apply',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
