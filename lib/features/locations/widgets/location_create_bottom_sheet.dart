import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/location_provider.dart';

class LocationCreateBottomSheet extends StatefulWidget {
  final int? defaultParentId;
  final String? defaultUsage;
  const LocationCreateBottomSheet({super.key, this.defaultParentId, this.defaultUsage});

  @override
  State<LocationCreateBottomSheet> createState() => _LocationCreateBottomSheetState();
}

class _LocationCreateBottomSheetState extends State<LocationCreateBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _usage = 'internal';
  final _parentIdCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _usage = widget.defaultUsage ?? 'internal';
    if (widget.defaultParentId != null) {
      _parentIdCtrl.text = widget.defaultParentId.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _parentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<LocationProvider>();
    setState(() => _submitting = true);
    try {
      final parentId = int.tryParse(_parentIdCtrl.text.trim());
      await provider.createLocation(
        name: _nameCtrl.text.trim(),
        usage: _usage,
        parentId: parentId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create location: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// §6 — field label above the input, with the red required marker.
  Widget _fieldLabel(String text, bool isDark, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: StatusColors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  /// §6 — filled field, transparent border, primary focus ring, red on error.
  InputDecoration _fieldDecoration(bool isDark, {String? hintText}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : AppTheme.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppTheme.primaryColor, 2),
      errorBorder: border(StatusColors.red),
      focusedErrorBorder: border(StatusColors.red, 2),
      errorStyle: const TextStyle(color: StatusColors.red, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Create Location',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Name', isDark, isRequired: true),
                    TextFormField(
                      controller: _nameCtrl,
                      style: valueStyle,
                      decoration: _fieldDecoration(
                        isDark,
                        hintText: 'Enter location name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Usage', isDark),
                    DropdownButtonFormField<String>(
                      value: _usage,
                      items: const [
                        DropdownMenuItem(value: 'internal', child: Text('internal')),
                        DropdownMenuItem(value: 'view', child: Text('view')),
                        DropdownMenuItem(value: 'customer', child: Text('customer')),
                        DropdownMenuItem(value: 'supplier', child: Text('supplier')),
                        DropdownMenuItem(value: 'inventory', child: Text('inventory')),
                        DropdownMenuItem(value: 'production', child: Text('production')),
                        DropdownMenuItem(value: 'transit', child: Text('transit')),
                      ],
                      onChanged: (v) => setState(() => _usage = v ?? 'internal'),
                      decoration: _fieldDecoration(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      elevation: 4,
                      menuMaxHeight: 320,
                      dropdownColor: isDark
                          ? AppTheme.darkPopupSurface
                          : Colors.white,
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Parent Location ID (optional)', isDark),
                    TextFormField(
                      controller: _parentIdCtrl,
                      keyboardType: TextInputType.number,
                      style: valueStyle,
                      decoration: _fieldDecoration(
                        isDark,
                        hintText: 'Enter numeric id',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _submitting ? 'Creating...' : 'Create',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
