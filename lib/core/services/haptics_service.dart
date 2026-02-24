import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Service for managing haptic feedback across the application.
class HapticsService {
  HapticsService._();

  /// Triggers a haptic feedback for a selection event.
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Triggers a light impact haptic feedback.
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Triggers a haptic sequence indicating a successful operation.
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await HapticFeedback.selectionClick();
  }

  static Future<void> warning() async {
    await HapticFeedback.lightImpact();
  }

  /// Triggers a haptic feedback indicating an error occurred.
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
  }

  /// Returns true if haptics are supported on the current platform.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;
}
