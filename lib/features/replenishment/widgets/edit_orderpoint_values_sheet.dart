import 'package:flutter/material.dart';

class EditOrderpointValuesResult {
  final double? minQty;
  final double? maxQty;
  final double? manualToOrderQty;
  const EditOrderpointValuesResult({this.minQty, this.maxQty, this.manualToOrderQty});
}

class EditOrderpointValuesSheet extends StatefulWidget {
  final double initialMin;
  final double initialMax;
  final double initialToOrder;

  const EditOrderpointValuesSheet({super.key, required this.initialMin, required this.initialMax, required this.initialToOrder});

  static Future<EditOrderpointValuesResult?> show(BuildContext context, {
    required double initialMin,
    required double initialMax,
    required double initialToOrder,
  }) {
    return showModalBottomSheet<EditOrderpointValuesResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditOrderpointValuesSheet(
        initialMin: initialMin,
        initialMax: initialMax,
        initialToOrder: initialToOrder,
      ),
    );
  }

  @override
  State<EditOrderpointValuesSheet> createState() => _EditOrderpointValuesSheetState();
}

class _EditOrderpointValuesSheetState extends State<EditOrderpointValuesSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _toOrderCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: widget.initialMin.toStringAsFixed(2));
    _maxCtrl = TextEditingController(text: widget.initialMax.toStringAsFixed(2));
    _toOrderCtrl = TextEditingController(text: widget.initialToOrder.toStringAsFixed(2));
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit Replenishment Values',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _numberField(context, label: 'Min', controller: _minCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(context, label: 'Max', controller: _maxCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              _numberField(context, label: 'Order Qty (Manual)', controller: _toOrderCtrl),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Colors.red[400], fontSize: 12))),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: theme.primaryColor),
                        foregroundColor: theme.primaryColor,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _numberField(BuildContext context, {required String label, required TextEditingController controller}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
      ),
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

    Navigator.pop(context, EditOrderpointValuesResult(minQty: min, maxQty: max, manualToOrderQty: toOrder));
  }
}
