import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
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
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter location name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
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
                      decoration: const InputDecoration(labelText: 'Usage'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _parentIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Parent Location ID (optional)',
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Creating...' : 'Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
