import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forms/mobo_search_dropdown_field.dart';
import '../utils/inventory_access.dart';

/// What the user chose in [CreateAdjustmentDialog].
class CreateAdjustmentResult {
  final int locationId;
  final double countedQuantity;

  /// Whether to apply the count right away. False for a user who may record
  /// counts but not apply them; a stock manager applies it later.
  final bool apply;

  const CreateAdjustmentResult({
    required this.locationId,
    required this.countedQuantity,
    this.apply = true,
  });
}

/// "Create Inventory Adjustment": pick an internal location and the counted
/// quantity, then create and apply the count. A user without the right to
/// apply adjustments gets "Save Count" instead, which records the count for
/// a stock manager to apply.
///
/// Laid out for short screens: the title bar and the Cancel / Create & Apply
/// footer stay on the dialog surface while the fields scroll between them,
/// and when even that does not fit (a landscape phone with the keyboard up)
/// the whole dialog scrolls as one. The footer never renders outside the
/// dialog. Pops a [CreateAdjustmentResult], or null when cancelled.
class CreateAdjustmentDialog extends StatefulWidget {
  /// `stock.location` rows with `id` and `complete_name` / `name`.
  final List<Map<String, dynamic>> locations;
  final int? initialLocationId;

  const CreateAdjustmentDialog({
    super.key,
    required this.locations,
    this.initialLocationId,
  });

  static Future<CreateAdjustmentResult?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> locations,
    int? initialLocationId,
  }) {
    return showDialog<CreateAdjustmentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateAdjustmentDialog(
        locations: locations,
        initialLocationId: initialLocationId,
      ),
    );
  }

  @override
  State<CreateAdjustmentDialog> createState() => _CreateAdjustmentDialogState();
}

class _CreateAdjustmentDialogState extends State<CreateAdjustmentDialog> {
  static const double _maxWidth = 480;
  static const double _buttonHeight = 48;

  /// Below this the pinned title + footer would leave the fields no room,
  /// so everything scrolls together instead.
  static const double _minHeightForPinnedChrome = 260;

  final TextEditingController _qtyController = TextEditingController();
  int? _locationId;
  String? _qtyError;

  /// Refreshed on every build from the user's access rights.
  bool _canApply = true;

  @override
  void initState() {
    super.initState();
    _locationId =
        widget.initialLocationId ??
        (widget.locations.isNotEmpty
            ? widget.locations.first['id'] as int?
            : null);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  String _locationLabel(int id) {
    final l = widget.locations.firstWhere(
      (e) => e['id'] == id,
      orElse: () => const {},
    );
    final complete = l['complete_name'];
    if (complete is String && complete.isNotEmpty) return complete;
    final name = l['name'];
    if (name is String && name.isNotEmpty) return name;
    return 'Location';
  }

  double? get _parsedQty =>
      double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));

  void _submit() {
    final qty = _parsedQty;
    final locationId = _locationId;
    if (qty == null || qty < 0) {
      setState(() => _qtyError = 'Enter a counted quantity of 0 or more');
      return;
    }
    if (locationId == null) return;
    Navigator.of(context).pop(
      CreateAdjustmentResult(
        locationId: locationId,
        countedQuantity: qty,
        apply: _canApply,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _canApply = InventoryAccess.watch(context).canApplyInventoryAdjustment;
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    return Dialog(
      // §19: fully rounded, flat.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      // Tighter insets than the 40/24 default so the buttons get room on a
      // narrow phone and the dialog gets height in landscape. The Dialog
      // itself adds the keyboard inset to these.
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 24 : 20,
        vertical: isLandscape ? 12 : 24,
      ),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: _maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _buildTitleBar(isDark);
          final fields = _buildFields(isDark);
          final footer = _buildFooter();

          if (constraints.maxHeight < _minHeightForPinnedChrome) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, fields, footer],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              Flexible(child: SingleChildScrollView(child: fields)),
              footer,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Create Inventory Adjustment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFields(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoboSearchDropdownField<int>(
            label: 'Location',
            hintText: 'Select location',
            isDark: isDark,
            showSearch: widget.locations.length > 8,
            selectedItem: _locationId,
            items: [for (final l in widget.locations) l['id'] as int],
            displayText: _locationLabel,
            onChanged: (v) => setState(() => _locationId = v ?? _locationId),
          ),
          const SizedBox(height: 16),
          _buildQuantityField(isDark),
          if (!_canApply) ...[
            const SizedBox(height: 12),
            Text(
              'The count is saved for a stock manager to apply.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// §6 quantity field: label above, filled field, primary focus ring.
  Widget _buildQuantityField(bool isDark) {
    final hasError = _qtyError != null;
    OutlineInputBorder border(Color? color, double width) => OutlineInputBorder(
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
      borderRadius: BorderRadius.circular(AppRadius.segment),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Counted Quantity',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const ValueKey('countedQuantityField'),
          controller: _qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_qtyError != null) setState(() => _qtyError = null);
          },
          onTapOutside: (_) {
            // §6: an emptied quantity reads back as 0.0 rather than blank.
            if (_qtyController.text.trim().isEmpty) {
              _qtyController.text = '0.0';
            }
            FocusManager.instance.primaryFocus?.unfocus();
          },
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Quantity',
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : AppTheme.inputFill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: border(hasError ? StatusColors.red : null, 1),
            focusedBorder: border(
              hasError ? StatusColors.red : AppTheme.primaryColor,
              2,
            ),
          ),
        ),
        // §6: custom error line, not the field's own errorText.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Padding(
                  key: const ValueKey('qtyError'),
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    _qtyError!,
                    style: const TextStyle(
                      color: StatusColors.red,
                      fontSize: 12,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// §5 two-button footer. Labels stay on one line and scale down to fit
  /// instead of wrapping.
  Widget _buildFooter() {
    Widget label(String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: _buttonHeight,
              child: OutlinedButton(
                key: const ValueKey('adjustmentCancelButton'),
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                  shape: shape,
                  padding: padding,
                ),
                child: label('Cancel'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: _buttonHeight,
              child: ElevatedButton(
                key: const ValueKey('adjustmentApplyButton'),
                onPressed: _locationId == null ? null : _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: shape,
                  padding: padding,
                ),
                child: label(_canApply ? 'Create & Apply' : 'Save Count'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
