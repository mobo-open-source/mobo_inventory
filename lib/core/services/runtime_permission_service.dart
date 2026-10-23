import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/widgets/dialogs/common_dialog.dart';

/// Service for handling runtime permission requests and displaying rationales.
class RuntimePermissionService {
  /// Requests microphone permission and shows a rationale dialog if denied.
  static Future<bool> requestMicrophonePermission(
    BuildContext context, {
    bool showRationale = true,
  }) async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (showRationale && context.mounted) {
        await _showPermissionDialog(
          context,
          'Microphone Permission',
          'Voice search requires microphone access. Please enable it in settings.',
        );
      }
      return false;
    }

    return false;
  }

  /// Requests camera permission and shows a rationale dialog if denied.
  static Future<bool> requestCameraPermission(
    BuildContext context, {
    bool showRationale = true,
  }) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (showRationale && context.mounted) {
        await _showPermissionDialog(
          context,
          'Camera Permission',
          'Barcode scanning requires camera access. Please enable it in settings.',
        );
      }
      return false;
    }

    return false;
  }

  static Future<void> _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) => CommonDialog(
        title: title,
        message: message,
        secondaryLabel: 'Not Now',
        onSecondary: () => Navigator.pop(context, false),
        primaryLabel: 'Open Settings',
        onPrimary: () => Navigator.pop(context, true),
      ),
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
    }
  }
}
