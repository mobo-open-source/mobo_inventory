import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_adjustment_model.dart';
import '../providers/adjustment_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/loaders/loading_indicator.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

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

  /// Whether the signed-in user may apply a count, not just record it.
  /// Fails open like [AccessRightsService]: allowed until Odoo says no, and
  /// allowed where no service is provided (some widget tests).
  bool _canApply(BuildContext context, {bool listen = true}) {
    try {
      final service = listen
          ? context.watch<AccessRightsService>()
          : context.read<AccessRightsService>();
      return service.canApplyInventoryAdjustment;
    } on ProviderNotFoundException {
      return true;
    }
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

    // Without apply rights the count is only recorded, for a stock manager to
    // apply — Odoo would refuse `action_apply_inventory` for this user.
    final canApply = _canApply(context, listen: false);

    if (quantity == 0) {
      final confirm = await CommonDialog.confirm(
        context,
        title: 'Set Count to Zero?',
        message:
            'You are about to set the counted quantity to 0. This will adjust stock to zero for this quant. Do you want to continue?',
        confirmText: canApply ? 'Yes, Apply' : 'Yes, Save',
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

    if (!canApply) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        CustomSnackbar.showSuccess(
          context,
          'Count saved. A stock manager needs to apply it.',
        );
        HapticsService.success();
        provider.refresh();
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

        ReviewService().trackSignificantEvent();
        // Let the success snackbar (a dialog route) dismiss itself before the
        // rating dialog is pushed, so its timer can't pop the wrong route.
        Future.delayed(const Duration(milliseconds: 3500), () {
          final targetContext = navigatorKey.currentContext;
          if (targetContext != null && targetContext.mounted) {
            ReviewService().checkAndShowRating(targetContext);
          }
        });
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
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: theme.primaryColor,
                      size: 22,
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
                            fontWeight: FontWeight.bold,
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
                      isDark ? StatusColors.infoIcon : StatusColors.blue,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Difference',
                      '${_difference >= 0 ? '+' : ''}${_difference.toStringAsFixed(2)}',
                      _difference > 0
                          ? (isDark
                                ? StatusColors.successIcon
                                : StatusColors.green)
                          : _difference < 0
                          ? (isDark ? StatusColors.errorIcon : StatusColors.red)
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
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              // §6 — quantity/numeric field.
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onTapOutside: (_) {
                  if (_quantityController.text.trim().isEmpty) {
                    _quantityController.text = '0.0';
                  }
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Counted Quantity',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : AppTheme.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.segment),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.segment),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(
                            color: theme.primaryColor,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _applyAdjustment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SmallLoadingIndicator(color: Colors.white)
                            : Text(
                                _canApply(context) ? 'Apply' : 'Save Count',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
