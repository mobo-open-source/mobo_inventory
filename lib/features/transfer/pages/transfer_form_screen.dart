import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../models/transfer_model.dart';
import '../../../shared/widgets/forms/overlay_dropdown.dart';
import '../../../shared/widgets/dialogs/loading_dialog.dart';
import '../../../shared/widgets/dialogs/quantity_dialog.dart';
import '../../../shared/widgets/bottom_sheets/product_selector_bottom_sheet.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/dialogs/confirm_discard_dialog.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../core/services/haptics_service.dart';

/// Screen for creating or editing an internal stock transfer with multiple line items.
class TransferFormScreen extends StatefulWidget {
  final InternalTransfer? transfer;

  const TransferFormScreen({super.key, this.transfer});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  String? _error;
  bool _dropdownsLoading = true;

  int? _selectedPickingTypeId;
  int? _selectedLocationId;
  int? _selectedLocationDestId;
  List<Map<String, dynamic>> _transferLines = [];
  DateTime? _scheduledDate;

  bool _isEditMode = false;
  bool _isReadOnly = false;
  bool _hasBeenSaved = false;

  bool _isAddingLine = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.transfer != null;

    if (_isEditMode) {
      final state = widget.transfer!.state;
      _isReadOnly = state == 'done';

      _selectedPickingTypeId = widget.transfer!.pickingTypeId;
      _selectedLocationId = widget.transfer!.locationId;
      _selectedLocationDestId = widget.transfer!.locationDestId;
      if (widget.transfer!.scheduledDate != null) {
        try {
          _scheduledDate = DateTime.parse(widget.transfer!.scheduledDate!);
        } catch (e) {}
      }

      if (widget.transfer!.moveLines.isNotEmpty) {
        _transferLines = widget.transfer!.moveLines.map((line) {
          dynamic extractId(dynamic value) {
            if (value is List && value.isNotEmpty) return value[0];
            if (value is String && value.startsWith('[')) {
              final match = RegExp(r'\[(\d+)').firstMatch(value);
              if (match != null) {
                return int.tryParse(match.group(1)!);
              }
            }
            return value;
          }

          return {
            'product_id': extractId(line.productId),
            'product_name': line.productName ?? 'Unknown Product',
            'product_uom': extractId(line.productUom ?? 1),
            'quantity': line.quantity,
          };
        }).toList();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<TransferProvider>();

    setState(() => _dropdownsLoading = true);

    try {
      await Future.wait([
        provider.fetchPickingTypes(),
        provider.fetchLocations(),
      ]);

      if (_isEditMode && widget.transfer != null) {
        await _loadTransferDetails();
      } else {
        _autoSelectInternalTransferType(provider);
      }

      setState(() {
        _dropdownsLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _dropdownsLoading = false;
        _error = 'Failed to load form data. Please try again.';
      });
    }
  }

  void _autoSelectInternalTransferType(TransferProvider provider) {
    final internalType = provider.pickingTypes.firstWhere((type) {
      final code = type['code']?.toString().toLowerCase() ?? '';
      final name = type['name']?.toString().toLowerCase() ?? '';
      return code == 'internal' || name.contains('internal');
    }, orElse: () => <String, dynamic>{});

    if (internalType.isNotEmpty && internalType['id'] != null) {
      setState(() {
        _selectedPickingTypeId = internalType['id'] as int;
      });
    }
  }

  Future<void> _loadTransferDetails() async {
    final provider = context.read<TransferProvider>();
    final transfer = await provider.fetchTransferDetails(widget.transfer!.id!);

    if (transfer != null && mounted) {
      setState(() {
        _selectedPickingTypeId = transfer.pickingTypeId;
        _selectedLocationId = transfer.locationId;
        _selectedLocationDestId = transfer.locationDestId;

        if (transfer.scheduledDate != null) {
          try {
            _scheduledDate = DateTime.parse(transfer.scheduledDate!);
          } catch (e) {}
        }

        _transferLines = transfer.moveLines.map((line) {
          dynamic extractId(dynamic value) {
            if (value is List && value.isNotEmpty) return value[0];
            if (value is String && value.startsWith('[')) {
              final match = RegExp(r'\[(\d+)').firstMatch(value);
              if (match != null) {
                return int.tryParse(match.group(1)!);
              }
            }
            return value;
          }

          return {
            'product_id': extractId(line.productId),
            'product_name': line.productName ?? 'Unknown Product',
            'product_uom': extractId(line.productUom ?? 1),
            'quantity': line.quantity,
            'unit_price': line.unitPrice,
          };
        }).toList();
      });
    }
  }

  bool get _hasUnsavedChanges {
    if (_dropdownsLoading || _hasBeenSaved) return false;

    if (!_isEditMode) {
      return _selectedPickingTypeId != null ||
          _selectedLocationId != null ||
          _selectedLocationDestId != null ||
          _scheduledDate != null ||
          _transferLines.isNotEmpty;
    }

    final t = widget.transfer;

    final baselineLines = (t?.moveLines ?? const []);
    return _selectedLocationId != t?.locationId ||
        _selectedLocationDestId != t?.locationDestId ||
        _scheduledDate?.toIso8601String() != t?.scheduledDate ||
        (baselineLines.isNotEmpty &&
            _transferLines.length != baselineLines.length);
  }

  Future<bool> _handleWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await ConfirmDiscardDialog.show(
      context,
      title: 'Discard Changes?',
      message:
          'You have unsaved changes that will be lost. Are you sure you want to discard them?',
      cancelLabel: 'Cancel',
      discardLabel: 'Discard',
    );

    return shouldPop ?? false;
  }

  void _addProductLine() async {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }

    final picked = await ProductSelectorBottomSheet.show(
      context,
      title: 'Select Product',
    );

    if (picked != null && mounted) {
      final selectedProduct = picked['product'] as Map<String, dynamic>;
      final quantity = (picked['quantity'] as num?)?.toDouble() ?? 1.0;

      final price = (selectedProduct['list_price'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _transferLines.add({
          'product_id': selectedProduct['id'],
          'product_name': selectedProduct['name'],
          'product_uom': selectedProduct['uom_id'] is List
              ? (selectedProduct['uom_id'] as List)[0]
              : 1,
          'quantity': quantity,
          'unit_price': price,
        });
        HapticsService.light();
      });
    }
  }

  void _removeProductLine(int index) {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }

    setState(() => _transferLines.removeAt(index));
    HapticsService.light();
  }

  Future<void> _editProductQuantity(int index) async {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }
    if (index < 0 || index >= _transferLines.length) return;
    final current = _transferLines[index];
    final newQty = await QuantityDialog.show(
      context,
      initialValue: (current['quantity'] as num?)?.toDouble() ?? 1,
    );
    if (newQty != null && newQty > 0) {
      setState(() {
        _transferLines[index]['quantity'] = newQty;
      });
      HapticsService.light();
    }
  }

  Future<void> _changeProduct(int index) async {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }

    final picked = await ProductSelectorBottomSheet.show(
      context,
      title: 'Select Product',
    );
    if (picked != null) {
      final selectedProduct = picked['product'] as Map<String, dynamic>;
      final quantity = (picked['quantity'] as num?)?.toDouble();
      final price = (selectedProduct['list_price'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _transferLines[index]['product_id'] = selectedProduct['id'];
        _transferLines[index]['product_name'] = selectedProduct['name'];
        _transferLines[index]['product_uom'] = selectedProduct['uom_id'] is List
            ? (selectedProduct['uom_id'] as List)[0]
            : 1;
        _transferLines[index]['unit_price'] = price;
        if (quantity != null && quantity > 0) {
          _transferLines[index]['quantity'] = quantity;
        }
      });
    }
  }

  Future<void> _saveTransfer() async {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }

    if (_selectedPickingTypeId == null ||
        _selectedLocationId == null ||
        _selectedLocationDestId == null ||
        _transferLines.isEmpty) {
      _showMessage(
        'Please fill all required fields and add at least one product',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    LoadingDialog.show(
      context,
      message: _isEditMode ? 'Updating transfer...' : 'Creating transfer...',
    );

    try {
      final provider = context.read<TransferProvider>();

      if (_isEditMode) {
        final success = await provider.updateInternalTransfer(
          transferId: widget.transfer!.id!,
          locationId: _selectedLocationId,
          locationDestId: _selectedLocationDestId,
          scheduledDate: _scheduledDate?.toIso8601String(),
          moveLines: _transferLines,
        );

        if (mounted) {
          LoadingDialog.hide(context);
          if (success) {
            setState(() => _hasBeenSaved = true);

            try {
              await context.read<DashboardProvider>().fetchStats(
                forceRefresh: true,
              );
            } catch (_) {}
            Navigator.pop(context, {
              'success': true,
              'message': 'Transfer updated successfully',
            });
            HapticsService.success();
          }
        }
      } else {
        final pickingId = await provider.createInternalTransfer(
          pickingTypeId: _selectedPickingTypeId!,
          locationId: _selectedLocationId!,
          locationDestId: _selectedLocationDestId!,
          moveLines: _transferLines,
          scheduledDate: _scheduledDate?.toIso8601String(),
        );

        if (mounted) {
          LoadingDialog.hide(context);

          if (pickingId != null) {
            setState(() => _hasBeenSaved = true);

            final markAsTodo = await _showMarkAsTodoDialog();

            String successMessage = 'Transfer created successfully';

            if (markAsTodo == true && mounted) {
              final markedSuccess = await _performMarkAsTodo(pickingId);
              if (markedSuccess) {
                successMessage =
                    'Transfer created and marked as todo successfully';
              }
            }

            if (mounted) {
              try {
                final newTransfer = await provider.fetchTransferDetails(
                  pickingId,
                );
                if (newTransfer != null && mounted) {
                  context.read<LastOpenedProvider>().trackTransferAccess(
                    transferId: newTransfer.id.toString(),
                    transferName: newTransfer.name,
                    state: newTransfer.state,
                    transferData: newTransfer.toJson(),
                  );
                }
              } catch (e) {}

              if (mounted) {
                try {
                  await context.read<DashboardProvider>().fetchStats(
                    forceRefresh: true,
                  );
                } catch (_) {}

                Navigator.pop(context, {
                  'success': true,
                  'message': successMessage,
                });
              }
              HapticsService.success();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.hide(context);
        setState(() => _isLoading = false);

        String errorMessage = 'Failed to save transfer';
        final errorStr = e.toString();

        if (errorStr.contains('message:')) {
          final match = RegExp(r'message:\s*([^,}]+)').firstMatch(errorStr);
          if (match != null) {
            errorMessage = match.group(1)?.trim() ?? errorMessage;
          }
        }

        _showMessage(errorMessage, isError: true);
        HapticsService.error();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showMarkAsTodoDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: 'Transfer Created',
        message: 'Would you like to mark this transfer as todo (confirm it)?',
        icon: Icons.task_alt,
        topIconCentered: true,
        secondaryLabel: 'Later',
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: 'Mark as Todo',
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
  }

  Future<bool> _performMarkAsTodo(int transferId) async {
    LoadingDialog.show(context, message: 'Marking as todo...');

    try {
      final provider = context.read<TransferProvider>();
      await provider.markAsTodo(transferId);

      if (mounted) {
        LoadingDialog.hide(context);

        try {
          await context.read<DashboardProvider>().fetchStats(
            forceRefresh: true,
          );
        } catch (_) {}
      }
      return true;
    } catch (e) {
      if (mounted) {
        LoadingDialog.hide(context);
        _showMessage('Failed to mark as todo: $e', isError: true);
      }
      return false;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    if (isError) {
      CustomSnackbar.showError(context, message);
    } else {
      CustomSnackbar.showSuccess(context, message);
    }
  }

  Widget _buildTransferTotals(bool isDark) {
    double subtotal = 0;
    for (var line in _transferLines) {
      final qty = (line['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (line['unit_price'] as num?)?.toDouble() ?? 0.0;
      subtotal += qty * price;
    }
    final tax = 0.0;
    final total = subtotal + tax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal:', subtotal, isDark),
          const SizedBox(height: 8),
          _buildTotalRow('Tax:', tax, isDark),
          const Divider(height: 24),
          _buildTotalRow('Total Amount:', total, isDark, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    bool isDark, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isDark
                ? Colors.grey[300]
                : (isTotal ? Colors.black87 : Colors.grey[700]),
          ),
        ),
        Text(
          '\$ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal
                ? Colors.blue
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final shouldPop = await _handleWillPop();
                if (shouldPop && mounted) Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          title: Text(
            _isEditMode
                ? (_isReadOnly ? 'View Transfer' : 'Edit Transfer')
                : 'Create Transfer',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (!_isReadOnly)
              IconButton(
                onPressed: () {
                  _loadInitialData();
                },
                icon: Icon(Icons.refresh, color: theme.primaryColor),
              ),
          ],
        ),
        body: _dropdownsLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : _buildForm(isDark, theme),
        bottomNavigationBar: _isReadOnly
            ? null
            : Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_transferLines.isEmpty || _isLoading)
                        ? null
                        : _saveTransfer,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            _isEditMode
                                ? HugeIcons.strokeRoundedFileEdit
                                : HugeIcons.strokeRoundedFileAdd,
                            color: Colors.white,
                            size: 20,
                          ),
                    label: Text(
                      _isLoading
                          ? (_isEditMode
                                ? 'Updating Transfer...'
                                : 'Creating Transfer...')
                          : (_isEditMode
                                ? 'Update Transfer'
                                : 'Create Transfer'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, ThemeData theme) {
    return Consumer<TransferProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfessionalCard(
                  title: 'Transfer Details',
                  icon: HugeIcons.strokeRoundedFile02,
                  children: [
                    if (!_isEditMode) ...[
                      OverlayDropdownField<int>(
                        value: _selectedPickingTypeId,
                        labelText: 'Transfer Type *',
                        hintText: 'Select transfer type',
                        isDark: isDark,
                        options: provider.pickingTypes.map((pt) {
                          final label = (() {
                            final dn = pt['display_name'];
                            final dnStr = dn == null
                                ? ''
                                : dn.toString().trim();
                            if (dnStr.isNotEmpty) return dnStr;
                            final n = pt['name'];
                            return n == null ? 'Unknown' : n.toString();
                          })();
                          return OverlayDropdownOption<int>(
                            value: pt['id'] as int,
                            label: label,
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPickingTypeId = value;

                            if (value != null) {
                              final pt = provider.pickingTypes.firstWhere(
                                (e) => (e['id'] as int) == value,
                                orElse: () => <String, dynamic>{},
                              );

                              dynamic src = pt['default_location_src_id'];
                              dynamic dest = pt['default_location_dest_id'];
                              int? srcId;
                              int? destId;
                              if (src is int)
                                srcId = src;
                              else if (src is List && src.isNotEmpty)
                                srcId = src[0] as int?;
                              if (dest is int)
                                destId = dest;
                              else if (dest is List && dest.isNotEmpty)
                                destId = dest[0] as int?;
                              if (srcId != null) _selectedLocationId = srcId;
                              if (destId != null)
                                _selectedLocationDestId = destId;
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    OverlayDropdownField<int>(
                      value: _selectedLocationId,
                      labelText: 'Source Location *',
                      hintText: 'Select source location',
                      isDark: isDark,
                      enabled: !_isReadOnly,
                      options: provider.locations.map((loc) {
                        final label =
                            loc['complete_name']?.toString() ??
                            loc['name']?.toString() ??
                            'Unknown';
                        return OverlayDropdownOption<int>(
                          value: loc['id'] as int,
                          label: label,
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedLocationId = value),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    OverlayDropdownField<int>(
                      value: _selectedLocationDestId,
                      labelText: 'Destination Location *',
                      hintText: 'Select destination location',
                      isDark: isDark,
                      enabled: !_isReadOnly,
                      options: provider.locations.map((loc) {
                        final label =
                            loc['complete_name']?.toString() ??
                            loc['name']?.toString() ??
                            'Unknown';
                        return OverlayDropdownOption<int>(
                          value: loc['id'] as int,
                          label: label,
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedLocationDestId = value),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    _buildDateField(isDark),
                  ],
                ),

                _buildProfessionalCard(
                  title: 'Products',
                  icon: HugeIcons.strokeRoundedShoppingBasket01,
                  children: [
                    if (!_isReadOnly)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _addProductLine,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.grey[800],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                HugeIcons.strokeRoundedShoppingBagAdd,
                                size: 20,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Add Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_transferLines.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              HugeIcons.strokeRoundedShoppingBasket01,
                              size: 48,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products added yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Add Product" to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          ...List.generate(_transferLines.length, (index) {
                            final line = _transferLines[index];
                            return _TransferLineItem(
                              line: line,
                              index: index,
                              isLast: index == _transferLines.length - 1,
                              isDark: isDark,
                              isReadOnly: _isReadOnly,
                              onEdit: () => _editProductQuantity(index),
                              onDelete: () => _removeProductLine(index),
                              onUpdate: (quantity, unitPrice) {
                                setState(() {
                                  _transferLines[index]['quantity'] = quantity;
                                  _transferLines[index]['unit_price'] =
                                      unitPrice;
                                });
                              },
                            );
                          }),
                          if (_isAddingLine) ...[
                            const SizedBox(height: 8),
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: isDark ? Colors.grey[850] : Colors.white,
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Adding product...'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    if (_transferLines.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTransferTotals(isDark),
                    ],
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfessionalCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
    bool showDivider = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[900],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              color: isDark ? Colors.grey[700] : Colors.grey[200],
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheduled Date',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isReadOnly
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _scheduledDate = date);
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _scheduledDate == null
                      ? 'Select date (optional)'
                      : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                  style: TextStyle(
                    color: _scheduledDate == null
                        ? (isDark ? Colors.white54 : Colors.grey[600])
                        : (isDark ? Colors.white70 : const Color(0xff000000)),
                    fontStyle: _scheduledDate == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontWeight: _scheduledDate == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                Icon(
                  HugeIcons.strokeRoundedCalendar03,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferLineItem extends StatefulWidget {
  final Map<String, dynamic> line;
  final int index;
  final bool isLast;
  final bool isDark;
  final bool isReadOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(double, double) onUpdate;

  const _TransferLineItem({
    required this.line,
    required this.index,
    required this.isLast,
    required this.isDark,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_TransferLineItem> createState() => _TransferLineItemState();
}

class _TransferLineItemState extends State<_TransferLineItem> {
  late double quantity;
  late double unitPrice;

  @override
  void initState() {
    super.initState();
    quantity = (widget.line['quantity'] as num?)?.toDouble() ?? 0.0;
    unitPrice = (widget.line['unit_price'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  void didUpdateWidget(_TransferLineItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newQuantity = (widget.line['quantity'] as num?)?.toDouble() ?? 0.0;
    final newUnitPrice = (widget.line['unit_price'] as num?)?.toDouble() ?? 0.0;
    if (newQuantity != quantity || newUnitPrice != unitPrice) {
      setState(() {
        quantity = newQuantity;
        unitPrice = newUnitPrice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = widget.isDark ? Colors.grey[850] : Colors.white;
    final borderColor = widget.isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = widget.isDark
        ? Colors.grey[400]
        : Colors.grey[600];
    final subtotal = quantity * unitPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.line['product_name']?.toString() ??
                              'Unnamed Product',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isReadOnly)
                    IconButton(
                      icon: Icon(
                        HugeIcons.strokeRoundedDelete02,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      tooltip: 'Delete',
                      onPressed: widget.onDelete,
                    ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _TransferQuantityInput(
                          initialValue: quantity,
                          onChanged: (value) {
                            if (value != quantity) {
                              setState(() => quantity = value);
                              widget.onUpdate(value, unitPrice);
                            }
                          },
                          isReadOnly: widget.isReadOnly,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Price',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _TransferPriceInput(
                          initialValue: unitPrice,
                          onChanged: (value) {
                            if (value != unitPrice) {
                              setState(() => unitPrice = value);
                              widget.onUpdate(quantity, value);
                            }
                          },
                          isReadOnly: widget.isReadOnly,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$ ${subtotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? Colors.white
                              : theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferQuantityInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isReadOnly;

  const _TransferQuantityInput({
    required this.initialValue,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  _TransferQuantityInputState createState() => _TransferQuantityInputState();
}

class _TransferQuantityInputState extends State<_TransferQuantityInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(0),
    );
    _controller.addListener(_onQuantityChanged);
  }

  @override
  void didUpdateWidget(_TransferQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      final newText = widget.initialValue.toStringAsFixed(0);
      if (_controller.text != newText) {
        _controller.removeListener(_onQuantityChanged);
        _controller.text = newText;
        _controller.addListener(_onQuantityChanged);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuantityChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    final value = double.tryParse(_controller.text) ?? 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(value > 0 ? value : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          border: Border.all(
            color: isDark ? Colors.grey[600]! : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: widget.isReadOnly
                  ? null
                  : () {
                      final currentValue =
                          double.tryParse(_controller.text) ?? 1.0;
                      if (currentValue > 1) {
                        _controller.text = (currentValue - 1)
                            .toInt()
                            .toString();
                      }
                    },
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(6),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                readOnly: widget.isReadOnly,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : null,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: widget.isReadOnly
                  ? null
                  : () {
                      final currentValue =
                          double.tryParse(_controller.text) ?? 0.0;
                      _controller.text = (currentValue + 1).toInt().toString();
                    },
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferPriceInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isReadOnly;

  const _TransferPriceInput({
    required this.initialValue,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  _TransferPriceInputState createState() => _TransferPriceInputState();
}

class _TransferPriceInputState extends State<_TransferPriceInput> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
    _controller.addListener(_onPriceChanged);
  }

  @override
  void didUpdateWidget(_TransferPriceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      final newText = widget.initialValue.toStringAsFixed(2);
      if (_controller.text != newText) {
        _controller.removeListener(_onPriceChanged);
        _controller.text = newText;
        _controller.addListener(_onPriceChanged);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPriceChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    final cleanText = _controller.text.replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleanText) ?? 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: widget.isReadOnly,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white : null,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
              top: 12,
              bottom: 12,
            ),
            child: Text(
              'USD',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[600]! : theme.dividerColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[600]! : theme.dividerColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.primaryColor),
          ),
        ),
      ),
    );
  }
}
