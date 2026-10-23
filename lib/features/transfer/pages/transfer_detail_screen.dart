import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/access_rights_service.dart';
import '../../replenishment/utils/replenishment_error.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/transfer_provider.dart';
import '../models/transfer_model.dart';
import '../utils/transfer_state_helper.dart';
import '../../../shared/widgets/dialogs/loading_dialog.dart';
import '../../../shared/widgets/cards/status_info_card.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../../../shared/widgets/loaders/shimmer_skeleton.dart';
import '../../../core/services/review_service.dart';
import '../../../main.dart';

/// Screen displaying the full details of a specific stock transfer, including line items and actions.
class TransferDetailScreen extends StatefulWidget {
  final InternalTransfer transfer;

  const TransferDetailScreen({super.key, required this.transfer});

  @override
  State<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  bool _isLoading = false;
  InternalTransfer? _currentTransfer;

  @override
  void initState() {
    super.initState();
    _currentTransfer = widget.transfer;

    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final provider = context.read<TransferProvider>();
    final transfer = await provider.fetchTransferDetails(widget.transfer.id!);
    if (transfer != null && mounted) {
      setState(() => _currentTransfer = transfer);

      context.read<LastOpenedProvider>().trackTransferAccess(
        transferId: transfer.id.toString(),
        transferName: transfer.name,
        state: transfer.state,
        transferData: transfer.toJson(),
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _editTransfer() async {
    if (_currentTransfer == null) return;

    final result = await context.pushNamed(
      AppRoutes.transferForm,
      extra: _currentTransfer,
    );

    if (result != null && mounted) {
      await _loadDetails();

      if (result is Map && result['success'] == true) {
        final message = result['message'] ?? 'Transfer updated successfully';
        CustomSnackbar.showSuccess(context, message);
      }
    }
  }

  Future<void> _markAsTodo() async {
    final moveLines = _currentTransfer?.moveLines;
    if (moveLines == null || moveLines.isEmpty) {
      CustomSnackbar.showWarning(
        context,
        'Please add at least one product to the transfer before marking as todo',
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Mark as Todo',
      'This will confirm the transfer and mark it as ready to process. Continue?',
      'Mark as Todo',
      StatusColors.blue,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      LoadingDialog.show(context, message: 'Marking as todo...');

      try {
        final provider = context.read<TransferProvider>();
        await provider.markAsTodo(_currentTransfer!.id!);

        if (mounted) {
          LoadingDialog.hide(context);
          _showMessage('Transfer marked as todo successfully');
          await _loadDetails();
        }
      } catch (e) {
        if (mounted) {
          LoadingDialog.hide(context);

          String errorMessage = 'Failed to mark as todo';
          final errorStr = e.toString();

          if (errorStr.contains('message:')) {
            final match = RegExp(r'message:\s*([^,}]+)').firstMatch(errorStr);
            if (match != null) {
              errorMessage = match.group(1)?.trim() ?? errorMessage;
            }
          }

          _showMessage(errorMessage, isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _validateTransfer() async {
    final moveLines = _currentTransfer?.moveLines;
    if (moveLines == null || moveLines.isEmpty) {
      CustomSnackbar.showWarning(
        context,
        'Cannot validate: No products in this transfer',
      );
      return;
    }

    if (!TransferStateHelper.canValidate(_currentTransfer?.state)) {
      CustomSnackbar.showWarning(
        context,
        'Transfer must be confirmed before validation',
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Validate Transfer',
      'This will process and complete the transfer. This action cannot be undone. Continue?',
      'Validate',
      StatusColors.green,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      LoadingDialog.show(context, message: 'Validating transfer...');

      try {
        final provider = context.read<TransferProvider>();
        await provider.validateTransfer(_currentTransfer!.id!);

        if (mounted) {
          LoadingDialog.hide(context);
          _showMessage('Transfer validated successfully');
          await _loadDetails();

          ReviewService().trackSignificantEvent();
          // Let the success snackbar (a dialog route) dismiss itself before the
          // rating dialog is pushed, so its timer can't pop the wrong route.
          Future.delayed(const Duration(milliseconds: 3500), () {
            final targetContext = navigatorKey.currentContext;
            if (targetContext != null && targetContext.mounted) {
              ReviewService().checkAndShowRating(targetContext);
            }
          });
        }
      } catch (e) {
        if (mounted) {
          LoadingDialog.hide(context);

          // Odoo's own UserError text; the top-level JSON-RPC message is only
          // the generic "Odoo Server Error".
          final errorMessage = e is AppException
              ? e.message
              : ReplenishmentError.from(e).message;

          _showMessage(errorMessage, isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelTransfer() async {
    if (!TransferStateHelper.canCancel(_currentTransfer?.state)) {
      if (_currentTransfer?.state == 'done') {
        CustomSnackbar.showWarning(
          context,
          'Cannot cancel: Transfer is already completed',
        );
      } else {
        CustomSnackbar.showInfo(context, 'Transfer is already cancelled');
      }
      return;
    }

    final confirm = await _showConfirmDialog(
      'Cancel Transfer',
      'Are you sure you want to cancel this transfer? This action cannot be undone.',
      'Yes, Cancel',
      StatusColors.red,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      LoadingDialog.show(context, message: 'Cancelling transfer...');

      try {
        final provider = context.read<TransferProvider>();
        await provider.cancelInternalTransfer(_currentTransfer!.id!);

        if (mounted) {
          LoadingDialog.hide(context);
          _showMessage('Transfer cancelled successfully');
          await _loadDetails();
        }
      } catch (e) {
        if (mounted) {
          LoadingDialog.hide(context);

          String errorMessage = 'Failed to cancel transfer';
          final errorStr = e.toString();

          if (errorStr.contains('message:')) {
            final match = RegExp(r'message:\s*([^,}]+)').firstMatch(errorStr);
            if (match != null) {
              errorMessage = match.group(1)?.trim() ?? errorMessage;
            }
          }

          _showMessage(errorMessage, isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showConfirmDialog(
    String title,
    String content,
    String actionLabel,
    Color actionColor,
  ) {
    IconData icon;
    final t = title.toLowerCase();
    if (t.contains('cancel')) {
      icon = Icons.warning_amber_rounded;
    } else if (t.contains('validate')) {
      icon = Icons.check_circle_outline;
    } else if (t.contains('todo')) {
      icon = Icons.task_alt;
    } else {
      icon = Icons.info_outline;
    }

    final bool destructive = actionColor == StatusColors.red;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: content,
        icon: icon,
        topIconCentered: true,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(false),
        primaryLabel: actionLabel,
        onPrimary: () => context.pop(true),
        destructivePrimary: destructive,
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    if (isError) {
      CustomSnackbar.showError(context, message);
    } else {
      CustomSnackbar.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final transfer = _currentTransfer ?? widget.transfer;
    // Actions the transfer's state allows and the user's access rights
    // permit; the rest are hidden.
    final access = context.watch<AccessRightsService>();
    final showEdit =
        TransferStateHelper.canEdit(transfer.state) &&
        TransferStateHelper.hasEditRights(access);
    final showCancel =
        TransferStateHelper.canCancel(transfer.state) &&
        TransferStateHelper.hasWriteRights(access);
    final showMarkAsTodo =
        TransferStateHelper.canMarkAsTodo(transfer.state) &&
        TransferStateHelper.hasWriteRights(access);
    final showValidate =
        TransferStateHelper.canValidate(transfer.state) &&
        TransferStateHelper.hasValidateRights(access);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        title: Text(
          'Transfer Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (showEdit)
            // A trailing AppBar action sits 12px from the edge, but the body
            // cards (and the leading arrow) sit at 16px. The 4px nudge lines
            // the icon up with the content below it.
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: Icon(
                  HugeIcons.strokeRoundedPencilEdit02,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                onPressed: _isLoading ? null : _editTransfer,
                tooltip: 'Edit',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton(isDark, theme)
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    StatusInfoCard(
                      title: transfer.name,
                      subtitle: transfer.pickingTypeName ?? 'Internal',
                      statusLabel: TransferStateHelper.getStateLabel(
                        transfer.state,
                      ),
                      statusColor: TransferStateHelper.getStateColor(
                        transfer.state,
                      ),
                      fields: [
                        StatusInfoField(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          label: 'Scheduled Date',
                          value: transfer.scheduledDate == null
                              ? '-'
                              : _formatDate(transfer.scheduledDate!),
                        ),
                        StatusInfoField(
                          icon: HugeIcons.strokeRoundedPackage,
                          label: 'Products',
                          value: '${transfer.moveLines.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInfoCard(
                      isDark,
                      children: [
                        Text(
                          'Locations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          'From',
                          transfer.locationName ?? 'Unknown',
                          isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildDetailRow(
                          'To',
                          transfer.locationDestName ?? 'Unknown',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInfoCard(
                      isDark,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Products',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${transfer.moveLines.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (transfer.moveLines.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No products',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          ...transfer.moveLines.map((line) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: isDark ? 0.2 : 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      HugeIcons.strokeRoundedPackage,
                                      size: 20,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.productName ?? 'Unknown Product',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Quantity: ${line.quantity}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar:
          _isLoading || (!showCancel && !showMarkAsTodo && !showValidate)
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),

              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showCancel)
                    Expanded(
                      child: _buildOutlinedButton(
                        label: 'Cancel',
                        icon: Icons.warning_amber_rounded,
                        onPressed: _cancelTransfer,
                      ),
                    ),
                  if (showCancel && (showMarkAsTodo || showValidate))
                    const SizedBox(width: 12),
                  if (showMarkAsTodo)
                    Expanded(
                      child: _buildFilledButton(
                        label: 'Mark as Todo',
                        icon: Icons.playlist_add_check,
                        onPressed: _markAsTodo,
                      ),
                    ),
                  if (showValidate)
                    Expanded(
                      child: _buildFilledButton(
                        label: 'Validate',
                        icon: Icons.check_circle,
                        onPressed: _validateTransfer,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.panel(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildFilledButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 18, color: theme.primaryColor),
        label: Text(
          label,
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: theme.primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSkeleton(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSkeletonCard(
            isDark,
            children: const [
              SkeletonLine(width: 140, height: 18),
              SizedBox(height: 16),
              SkeletonLine(width: 200),
              SizedBox(height: 8),
              SkeletonLine(width: 160),
              SizedBox(height: 8),
              SkeletonLine(width: 120),
            ],
          ),
          const SizedBox(height: 16),
          _buildSkeletonCard(
            isDark,
            children: const [
              SkeletonLine(width: 120, height: 18),
              SizedBox(height: 16),
              SkeletonLine(width: double.infinity),
              SizedBox(height: 8),
              SkeletonLine(width: double.infinity),
            ],
          ),
          const SizedBox(height: 16),
          _buildSkeletonCard(
            isDark,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonLine(width: 120, height: 18),
                  SkeletonBox(height: 20, width: 40),
                ],
              ),
              const SizedBox(height: 16),

              for (int i = 0; i < 3; i++) ...[
                Row(
                  children: const [
                    SkeletonBox(
                      height: 36,
                      width: 36,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonLine()),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.panel(isDark),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
