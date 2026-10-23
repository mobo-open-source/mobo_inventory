import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forms/mobo_search_dropdown_field.dart';

class EditOrderpointValuesResult {
  final double? minQty;
  final double? maxQty;
  final double? manualToOrderQty;

  /// The new location, or null when it was left unchanged.
  final int? locationId;
  const EditOrderpointValuesResult({
    this.minQty,
    this.maxQty,
    this.manualToOrderQty,
    this.locationId,
  });
}

class EditOrderpointValuesSheet extends StatefulWidget {
  final double initialMin;
  final double initialMax;
  final double initialToOrder;
  final int? initialLocationId;
  final String initialLocationName;

  /// Loads the locations to choose from (`id` and `complete_name` rows).
  final Future<List<Map<String, dynamic>>> Function()? loadLocations;

  const EditOrderpointValuesSheet({
    super.key,
    required this.initialMin,
    required this.initialMax,
    required this.initialToOrder,
    this.initialLocationId,
    this.initialLocationName = '',
    this.loadLocations,
  });

  static Future<EditOrderpointValuesResult?> show(
    BuildContext context, {
    required double initialMin,
    required double initialMax,
    required double initialToOrder,
    int? initialLocationId,
    String initialLocationName = '',
    Future<List<Map<String, dynamic>>> Function()? loadLocations,
  }) {
    return showModalBottomSheet<EditOrderpointValuesResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditOrderpointValuesSheet(
        initialMin: initialMin,
        initialMax: initialMax,
        initialToOrder: initialToOrder,
        initialLocationId: initialLocationId,
        initialLocationName: initialLocationName,
        loadLocations: loadLocations,
      ),
    );
  }

  @override
  State<EditOrderpointValuesSheet> createState() =>
      _EditOrderpointValuesSheetState();
}

class _EditOrderpointValuesSheetState extends State<EditOrderpointValuesSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _toOrderCtrl;
  String? _error;

  int? _locationId;

  /// Location names by id; holds the current location until the rest load.
  Map<int, String> _locations = {};
  bool _loadingLocations = false;

  @override
  void initState() {
    super.initState();
    _locationId = widget.initialLocationId;
    if (_locationId != null) {
      _locations = {_locationId!: widget.initialLocationName};
    }
    _loadLocations();
    _minCtrl = TextEditingController(
      text: widget.initialMin.toStringAsFixed(2),
    );
    _maxCtrl = TextEditingController(
      text: widget.initialMax.toStringAsFixed(2),
    );
    _toOrderCtrl = TextEditingController(
      text: widget.initialToOrder.toStringAsFixed(2),
    );
  }

  Future<void> _loadLocations() async {
    final load = widget.loadLocations;
    if (load == null) return;
    setState(() => _loadingLocations = true);
    try {
      final rows = await load();
      if (!mounted) return;
      setState(() {
        _locations = {
          ..._locations,
          for (final r in rows)
            r['id'] as int: r['complete_name']?.toString() ?? '',
        };
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load locations');
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _toOrderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        // Scrolls when the form doesn't fit (a phone in landscape, or with
        // the keyboard up); sized to its content otherwise.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Edit Replenishment Values',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.loadLocations != null) ...[
                  MoboSearchDropdownField<int>(
                    label: 'Location',
                    hintText: 'Select location',
                    searchHint: 'Search locations...',
                    isDark: isDark,
                    isLoading: _loadingLocations,
                    selectedItem: _locationId,
                    items: _locations.keys.toList(),
                    displayText: (id) => _locations[id] ?? '',
                    onChanged: (id) =>
                        setState(() => _locationId = id ?? _locationId),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        context,
                        label: 'Min',
                        controller: _minCtrl,
                        defaultWhenEmpty: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        context,
                        label: 'Max',
                        controller: _maxCtrl,
                        defaultWhenEmpty: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numberField(
                  context,
                  label: 'Order Qty (Manual)',
                  controller: _toOrderCtrl,
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: StatusColors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.primaryColor,
                              width: 1.5,
                            ),
                            foregroundColor: theme.primaryColor,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                          onPressed: _onSave,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  /// §6 quantity/numeric field. [defaultWhenEmpty] fills in "0.0" when the
  /// field is left blank; the manual order qty keeps blank as "not set".
  Widget _numberField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    bool defaultWhenEmpty = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTapOutside: (_) {
            if (defaultWhenEmpty && controller.text.trim().isEmpty) {
              controller.text = '0.0';
            }
            FocusManager.instance.primaryFocus?.unfocus();
          },
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : AppTheme.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.segment),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.segment),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.segment),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onSave() {
    setState(() => _error = null);

    double? parse(String s) {
      final v = double.tryParse(s.trim());
      return v;
    }

    final min = parse(_minCtrl.text);
    final max = parse(_maxCtrl.text);
    final toOrder = parse(_toOrderCtrl.text);

    if (min == null || max == null) {
      _error = 'Min and Max are required numbers';
      setState(() {});
      return;
    }
    if (min < 0 || max < 0) {
      _error = 'Values cannot be negative';
      setState(() {});
      return;
    }
    if (min > max) {
      _error = 'Min cannot be greater than Max';
      setState(() {});
      return;
    }
    if (toOrder != null && toOrder < 0) {
      _error = 'Order qty cannot be negative';
      setState(() {});
      return;
    }

    Navigator.pop(
      context,
      EditOrderpointValuesResult(
        minQty: min,
        maxQty: max,
        manualToOrderQty: toOrder,
        locationId: _locationId != widget.initialLocationId
            ? _locationId
            : null,
      ),
    );
  }
}
