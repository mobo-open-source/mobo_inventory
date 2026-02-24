import 'package:flutter/material.dart';
import '../providers/warehouse_provider.dart';

class WarehouseCreateBottomSheet extends StatefulWidget {
  final WarehouseProvider provider;
  const WarehouseCreateBottomSheet({super.key, required this.provider});

  @override
  State<WarehouseCreateBottomSheet> createState() => _WarehouseCreateBottomSheetState();
}

class _WarehouseCreateBottomSheetState extends State<WarehouseCreateBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  List<Map<String, dynamic>> _companies = const [];
  int? _selectedCompanyId;
  int? _selectedPartnerId;
  bool _loadingCompanies = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = widget.provider;
      try {
        final data = await provider.fetchCompanies();
        if (!mounted) return;
        setState(() {
          _companies = data;

          if (_companies.isNotEmpty) {
            _selectedCompanyId = (_companies.first['id'] as int?);
          }
          _loadingCompanies = false;
        });

        if (_selectedCompanyId != null) {
          await _onCompanyChanged(_selectedCompanyId!);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _loadingCompanies = false);
      }
    });
  }

  Future<void> _onCompanyChanged(int companyId) async {
    final provider = widget.provider;
    try {

      final detail = await provider.fetchCompanyDetail(companyId);
      if (detail != null) {
        final partner = detail['partner_id'];
        if (partner is List && partner.isNotEmpty) {
          _selectedPartnerId = partner[0] as int?;
        } else if (partner is Map) {
          _selectedPartnerId = partner['id'] as int?;
        }

        final count = await provider.getWarehouseCountByCompany(companyId);
        final compName = (detail['name'] ?? '').toString();
        if (_nameCtrl.text.trim().isEmpty || _nameCtrl.text.contains('warehouse #')) {
          setState(() {
            _nameCtrl.text = '$compName - warehouse # ${count + 1}';
          });
        }
      }
    } catch (_) {

    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = widget.provider;
    setState(() => _submitting = true);
    try {
      await provider.createWarehouse(
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        companyId: _selectedCompanyId!,
        partnerId: _selectedPartnerId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create warehouse: $e')),
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
      height: MediaQuery.of(context).size.height * 0.6,
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
                    'Create Warehouse',
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
                        hintText: 'Enter warehouse name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Short Name (Code)',
                        hintText: 'e.g. CW',
                      ),
                      maxLength: 5,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Short Name is required';
                        if (val.length > 5) return 'Max 5 characters';
                        return null;
                      },
                      onChanged: (v) {

                        final upper = v.toUpperCase();
                        if (upper != v) {
                          final sel = _codeCtrl.selection;
                          _codeCtrl.value = TextEditingValue(text: upper, selection: sel);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _loadingCompanies
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                        : DropdownButtonFormField<int>(
                            value: _selectedCompanyId,
                            decoration: const InputDecoration(
                              labelText: 'Company',
                            ),
                            items: _companies
                                .map((c) => DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text((c['name'] ?? '').toString()),
                                    ))
                                .toList(),
                            onChanged: (v) async {
                              setState(() => _selectedCompanyId = v);
                              if (v != null) {
                                await _onCompanyChanged(v);
                              }
                            },
                            validator: (v) => v == null ? 'Please select a company' : null,
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
