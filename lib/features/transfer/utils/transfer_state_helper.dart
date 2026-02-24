import 'package:flutter/material.dart';

/// Helper class for managing and formatting transfer states and their visual representations.
class TransferStateHelper {
  static String getStateLabel(String? state) {
    if (state == null) return 'Unknown';

    switch (state) {
      case 'draft':
        return 'Draft';
      case 'waiting':
        return 'Waiting Another Operation';
      case 'confirmed':
        return 'Waiting';
      case 'assigned':
        return 'Ready';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  static Color getStateColor(String? state) {
    if (state == null) return Colors.grey;

    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'waiting':
      case 'confirmed':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static bool canEdit(String? state) {
    return state != 'done' && state != 'cancel';
  }

  static bool canMarkAsTodo(String? state) {
    return state == 'draft';
  }

  static bool canValidate(String? state) {
    return state == 'confirmed' || state == 'waiting' || state == 'assigned';
  }

  static bool canCancel(String? state) {
    return state != 'done' && state != 'cancel';
  }
}
