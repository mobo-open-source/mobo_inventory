import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

/// A versatile badge widget for displaying statuses (e.g., transfers, orders, invoices) with consistent styling.
class StatusBadge extends StatelessWidget {
  final String status;
  final StatusBadgeStyle? style;

  const StatusBadge({super.key, required this.status, this.style});

  factory StatusBadge.transfer(String state) {
    return StatusBadge(status: state, style: _getTransferStyle(state));
  }

  factory StatusBadge.order(String state) {
    return StatusBadge(status: state, style: _getOrderStyle(state));
  }

  factory StatusBadge.invoice(String state) {
    return StatusBadge(status: state, style: _getInvoiceStyle(state));
  }

  static StatusBadgeStyle _getTransferStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(
          label: 'Draft',
          color: StatusColors.forState('draft'),
          icon: HugeIcons.strokeRoundedPencilEdit02,
        );
      case 'waiting':
        return StatusBadgeStyle(
          label: 'Waiting',
          color: StatusColors.forState('waiting'),
          icon: Icons.hourglass_empty,
        );
      case 'confirmed':
        return StatusBadgeStyle(
          label: 'Waiting',
          color: StatusColors.forState('waiting'),
          icon: Icons.hourglass_empty,
        );
      case 'assigned':
        return StatusBadgeStyle(
          label: 'Ready',
          color: StatusColors.forState('assigned'),
          icon: Icons.assignment_turned_in_outlined,
        );
      case 'done':
        return StatusBadgeStyle(
          label: 'Done',
          color: StatusColors.forState('done'),
          icon: Icons.check_circle,
        );
      case 'cancel':
      case 'cancelled':
        return StatusBadgeStyle(
          label: 'Cancelled',
          color: StatusColors.forState('cancel'),
          icon: Icons.cancel_outlined,
        );
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getOrderStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: StatusColors.orange);
      case 'sent':
        return StatusBadgeStyle(label: 'Sent', color: StatusColors.blue);
      case 'sale':
        return StatusBadgeStyle(label: 'Sale Order', color: StatusColors.green);
      case 'done':
        return StatusBadgeStyle(label: 'Done', color: StatusColors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: StatusColors.red);
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getInvoiceStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: StatusColors.orange);
      case 'posted':
        return StatusBadgeStyle(label: 'Posted', color: StatusColors.green);
      case 'paid':
        return StatusBadgeStyle(label: 'Paid', color: StatusColors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: StatusColors.red);
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeStyle =
        style ?? StatusBadgeStyle(label: status, color: StatusColors.grey);

    // §10 — the canonical status badge.
    return StatusColors.buildStatusBadge(
      badgeStyle.label,
      badgeStyle.color,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }
}

/// Defines the visual style for a [StatusBadge].
class StatusBadgeStyle {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadgeStyle({required this.label, required this.color, this.icon});
}
