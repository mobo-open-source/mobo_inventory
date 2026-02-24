import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'common_dialog.dart';

/// A specialized confirmation dialog for discarding unsaved changes.
class ConfirmDiscardDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String discardLabel;

  const ConfirmDiscardDialog({
    super.key,
    this.title = 'Discard Changes?',
    this.message =
        'You have unsaved changes that will be lost. Are you sure you want to discard them?',
    this.cancelLabel = 'Stay',
    this.discardLabel = 'Leave',
  });

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: title,
      message: message,
      icon: HugeIcons.strokeRoundedAlert02,
      topIconCentered: true,
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.pop(context, false),
      primaryLabel: discardLabel,
      destructivePrimary: true,
      onPrimary: () => Navigator.pop(context, true),
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    String title = 'Discard Changes?',
    String message =
        'You have unsaved changes that will be lost. Are you sure you want to discard them?',
    String cancelLabel = 'Stay',
    String discardLabel = 'Leave',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDiscardDialog(
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        discardLabel: discardLabel,
      ),
    );
  }
}
