import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
      height: MediaQuery.of(context).size.height * 0.6,
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
                    _fieldLabel('Name', isDark, isRequired: true),
                    TextFormField(
                      controller: _nameCtrl,
                      style: valueStyle,
                      decoration: _fieldDecoration(
                        isDark,
                        hintText: 'Enter warehouse name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Short Name (Code)', isDark, isRequired: true),
                    TextFormField(
                      controller: _codeCtrl,
                      style: valueStyle,
                      decoration: _fieldDecoration(isDark, hintText: 'e.g. CW'),
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
                    _fieldLabel('Company', isDark, isRequired: true),
                    _loadingCompanies
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                        : DropdownButtonFormField<int>(
                            value: _selectedCompanyId,
                            decoration: _fieldDecoration(isDark),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            elevation: 4,
                            menuMaxHeight: 320,
                            dropdownColor: isDark
                                ? AppTheme.darkPopupSurface
                                : Colors.white,
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
