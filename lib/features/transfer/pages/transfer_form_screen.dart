import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../models/transfer_model.dart';
import '../utils/transfer_state_helper.dart';
import '../../../shared/widgets/cards/status_info_card.dart';
import '../../../shared/widgets/forms/mobo_typeahead_dropdown_field.dart';
import '../../../shared/widgets/forms/mobo_date_picker.dart';
import '../../../shared/widgets/forms/mobo_product_search_field.dart';
import '../../../shared/widgets/dialogs/loading_dialog.dart';
import '../../../shared/widgets/dialogs/quantity_dialog.dart';
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

    _captureBaseline();

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
      } else if (mounted) {
        _autoSelectInternalTransferType(provider);
      }

      if (!mounted) return;
      setState(() {
        _dropdownsLoading = false;
        _error = null;
        _captureBaseline();
      });
    } catch (e) {
      if (!mounted) return;
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

  /// Snapshot of the form as the user first sees it, taken once loading
  /// settles. Diffing against this — rather than against widget.transfer —
  /// means values the form fills in by itself (the auto-selected transfer
  /// type, everything refreshed from the server) count as the starting
  /// point rather than as edits, and no date/string formats have to line up.
  int? _baselinePickingTypeId;
  int? _baselineLocationId;
  int? _baselineLocationDestId;
  DateTime? _baselineScheduledDate;
  String _baselineLines = '';

  String _linesSignature() => _transferLines
      .map((l) => '${l['product_id']}:${l['quantity']}:${l['unit_price']}')
      .join('|');

  void _captureBaseline() {
    _baselinePickingTypeId = _selectedPickingTypeId;
    _baselineLocationId = _selectedLocationId;
    _baselineLocationDestId = _selectedLocationDestId;
    _baselineScheduledDate = _scheduledDate;
    _baselineLines = _linesSignature();
  }

  bool get _hasUnsavedChanges {
    if (_dropdownsLoading || _hasBeenSaved) return false;

    return _selectedPickingTypeId != _baselinePickingTypeId ||
        _selectedLocationId != _baselineLocationId ||
        _selectedLocationDestId != _baselineLocationDestId ||
        _scheduledDate != _baselineScheduledDate ||
        _linesSignature() != _baselineLines;
  }

  bool get _requiredFieldsFilled =>
      _selectedLocationId != null &&
      _selectedLocationDestId != null &&
      (_isEditMode || _selectedPickingTypeId != null);

  bool get _canSave =>
      !_isLoading &&
      !_isReadOnly &&
      // A created transfer is never created a second time from this form.
      !(_hasBeenSaved && !_isEditMode) &&
      _transferLines.isNotEmpty &&
      _requiredFieldsFilled &&
      (!_isEditMode || _hasUnsavedChanges);

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

  void _onProductAdded(Map<String, dynamic> picked) {
    if (_isReadOnly) {
      _showMessage('Cannot edit a completed transfer', isError: true);
      return;
    }

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

            unawaited(_refreshDashboard(context.read<DashboardProvider>()));
            _popSelf({
              'success': true,
              'message': 'Transfer updated successfully',
            });
            HapticsService.success();
          } else {
            _showMessage(
              provider.error ?? 'Failed to update transfer',
              isError: true,
            );
            HapticsService.error();
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
            bool markFailed = false;

            if (markAsTodo == true && mounted) {
              final markedSuccess = await _performMarkAsTodo(pickingId);
              markFailed = !markedSuccess;
              successMessage = markedSuccess
                  ? 'Transfer created and marked as todo successfully'
                  : 'Transfer created, but it could not be marked as todo';
            }

            if (mounted) {
              // Recorded after the form closes: awaiting these first left
              // the form open and interactive for a dozen RPCs, and a back
              // press in that window made the late pop close the page below
              // it instead — blanking the app.
              unawaited(
                _recordCreatedTransfer(
                  pickingId,
                  provider,
                  context.read<LastOpenedProvider>(),
                  context.read<DashboardProvider>(),
                ),
              );

              _popSelf({
                'success': true,
                'message': successMessage,
                if (markFailed) 'warning': true,
              });

              ReviewService().trackSignificantEvent();
              // Let the success snackbar (a dialog route) dismiss itself
              // before the rating dialog is pushed, so its timer can't pop
              // the wrong route.
              Future.delayed(const Duration(milliseconds: 3500), () {
                final targetContext = navigatorKey.currentContext;
                if (targetContext != null && targetContext.mounted) {
                  ReviewService().checkAndShowRating(targetContext);
                }
              });
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

  /// The dashboard is refreshed once the form has closed; the failure is
  /// reported by the screen the form returns to, since closing the form
  /// would close a snackbar shown here.
  Future<bool> _performMarkAsTodo(int transferId) async {
    LoadingDialog.show(context, message: 'Marking as todo...');

    try {
      final provider = context.read<TransferProvider>();
      await provider.markAsTodo(transferId);

      if (mounted) LoadingDialog.hide(context);
      return true;
    } catch (e) {
      if (mounted) LoadingDialog.hide(context);
      return false;
    }
  }

  /// Closes this form with [result] — and only this form. `Navigator.pop`
  /// closes whatever route is on top, so after a back press (the form
  /// already closing) or with a dialog or picker above it, it closed the
  /// wrong route: the shell page below, leaving the app blank.
  void _popSelf(Object? result) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    if (route.isCurrent) navigator.pop(result);
  }

  static Future<void> _refreshDashboard(DashboardProvider dashboard) async {
    try {
      await dashboard.fetchStats(forceRefresh: true);
    } catch (_) {}
  }

  /// Adds the new transfer to "Recently opened" and refreshes the
  /// dashboard. Takes the providers rather than reading them from
  /// `context`, which is gone by the time this finishes.
  static Future<void> _recordCreatedTransfer(
    int pickingId,
    TransferProvider transfers,
    LastOpenedProvider lastOpened,
    DashboardProvider dashboard,
  ) async {
    try {
      final newTransfer = await transfers.fetchTransferDetails(pickingId);
      if (newTransfer != null) {
        await lastOpened.trackTransferAccess(
          transferId: newTransfer.id.toString(),
          transferName: newTransfer.name,
          state: newTransfer.state,
          transferData: newTransfer.toJson(),
        );
      }
    } catch (_) {}
    await _refreshDashboard(dashboard);
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
            ? Colors.white.withValues(alpha: .1)
            : StatusColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .3)
              : StatusColors.blue.withValues(alpha: 0.3),
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
                ? StatusColors.blue
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
      // Not while saving: the save pops the form itself when it is done.
      canPop: !_isLoading && !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop || _isLoading) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            onPressed: () async {
              if (_isLoading) return;
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
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton(
                  onPressed: () {
                    _loadInitialData();
                  },
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
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
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _canSave ? _saveTransfer : null,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      disabledForegroundColor: isDark
                          ? Colors.grey[400]
                          : Colors.grey[500],
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
            Icon(Icons.error_outline, size: 64, color: StatusColors.errorIcon),
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
                if (_isEditMode && widget.transfer != null) ...[
                  StatusInfoCard(
                    title: widget.transfer!.name,
                    subtitle: widget.transfer!.pickingTypeName ?? 'Internal',
                    statusLabel: TransferStateHelper.getStateLabel(
                      widget.transfer!.state,
                    ),
                    statusColor: TransferStateHelper.getStateColor(
                      widget.transfer!.state,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                _buildProfessionalCard(
                  title: 'Transfer Details',
                  icon: HugeIcons.strokeRoundedFile02,
                  children: [
                    if (!_isEditMode) ...[
                      MoboTypeaheadDropdownField<int>(
                        label: 'Transfer Type',
                        isRequired: true,
                        hintText: 'Select transfer type',
                        isDark: isDark,
                        selectedItem: _selectedPickingTypeId,
                        items: [
                          for (final pt in provider.pickingTypes)
                            pt['id'] as int,
                        ],
                        displayText: (id) {
                          final pt = provider.pickingTypes.firstWhere(
                            (e) => (e['id'] as int) == id,
                            orElse: () => <String, dynamic>{},
                          );
                          final dn = pt['display_name'];
                          final dnStr = dn == null ? '' : dn.toString().trim();
                          if (dnStr.isNotEmpty) return dnStr;
                          final n = pt['name'];
                          return n == null ? 'Unknown' : n.toString();
                        },
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
                      ),
                      const SizedBox(height: 12),
                    ],

                    IgnorePointer(
                      ignoring: _isReadOnly,
                      child: MoboTypeaheadDropdownField<int>(
                        label: 'Source Location',
                        isRequired: true,
                        hintText: 'Select source location',
                        isDark: isDark,
                        selectedItem: _selectedLocationId,
                        items: [
                          for (final loc in provider.locations)
                            loc['id'] as int,
                        ],
                        displayText: (id) {
                          final loc = provider.locations.firstWhere(
                            (e) => e['id'] == id,
                            orElse: () => <String, dynamic>{},
                          );
                          return loc['complete_name']?.toString() ??
                              loc['name']?.toString() ??
                              'Unknown';
                        },
                        onChanged: (value) =>
                            setState(() => _selectedLocationId = value),
                      ),
                    ),
                    const SizedBox(height: 12),

                    IgnorePointer(
                      ignoring: _isReadOnly,
                      child: MoboTypeaheadDropdownField<int>(
                        label: 'Destination Location',
                        isRequired: true,
                        hintText: 'Select destination location',
                        isDark: isDark,
                        selectedItem: _selectedLocationDestId,
                        items: [
                          for (final loc in provider.locations)
                            loc['id'] as int,
                        ],
                        displayText: (id) {
                          final loc = provider.locations.firstWhere(
                            (e) => e['id'] == id,
                            orElse: () => <String, dynamic>{},
                          );
                          return loc['complete_name']?.toString() ??
                              loc['name']?.toString() ??
                              'Unknown';
                        },
                        onChanged: (value) =>
                            setState(() => _selectedLocationDestId = value),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDateField(isDark),
                  ],
                ),

                _buildProfessionalCard(
                  title: 'Products',
                  icon: HugeIcons.strokeRoundedShoppingBasket01,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_transferLines.length}',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  children: [
                    if (!_isReadOnly)
                      MoboProductSearchField(
                        isDark: isDark,
                        onProductAdded: _onProductAdded,
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
                              'Search above to add your first product',
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
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: AppTheme.cardDecoration(isDark),
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
    Widget? trailing,
    bool showDivider = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppTheme.panelDecoration(isDark),
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
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                    letterSpacing: -0.3,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
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
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isReadOnly
              ? null
              : () async {
                  final date = await MoboDatePicker.show(
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
              color: isDark ? Colors.grey[850] : AppTheme.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _scheduledDate == null
                      ? 'Select date (optional)'
                      : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                  // The base style the dropdowns' text is drawn from, so the
                  // date reads at their size (16) and the box is as tall.
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: _scheduledDate == null
                        ? (isDark ? Colors.grey[400] : Colors.grey[600])
                        : (isDark ? Colors.white : Colors.black87),
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
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    final secondaryTextColor = widget.isDark
        ? Colors.grey[400]
        : Colors.grey[600];
    final subtotal = quantity * unitPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(widget.isDark),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                          color: widget.isDark
                              ? Colors.white
                              : theme.primaryColor,
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
                      color: StatusColors.red,
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: widget.onDelete,
                  ),
              ],
            ),

            const SizedBox(height: 12),
            // The two inputs share the row's full width: with the Total
            // beside them each was ~88px, too narrow for the price once its
            // "USD" prefix took its share.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
                Text(
                  '\$ ${subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The decoration of the Quantity and Unit Price inputs. One definition, so
/// the two are the same height with their text on the same line: the padding
/// centres a single line in the 40px field, and the prefix (the currency)
/// takes only its own height, so it cannot push the text off-centre.
InputDecoration _lineInputDecoration({
  required bool isDark,
  required double horizontalPadding,
  String? hintText,
  Widget? prefix,
}) {
  OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.segment),
        borderSide: side,
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
    isDense: true,
    counterText: '',
    contentPadding: EdgeInsets.symmetric(
      vertical: 10,
      horizontal: horizontalPadding,
    ),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(
      const BorderSide(color: AppTheme.primaryColor, width: 2),
    ),
  );
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

    // §6 quantity/numeric field — a plain numeric field, not a +/- stepper.
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        readOnly: widget.isReadOnly,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: _lineInputDecoration(
          isDark: isDark,
          horizontalPadding: 4,
          hintText: 'Quantity',
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
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: _lineInputDecoration(
          isDark: isDark,
          horizontalPadding: 12,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Text(
              'USD',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
