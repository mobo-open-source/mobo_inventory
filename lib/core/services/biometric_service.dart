import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing biometric authentication (Fingerprint, Face ID, etc.).
class BiometricService {
  static LocalAuthentication? _localAuth;
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _localAuth = LocalAuthentication();
      _isInitialized = true;
    }
  }

  @visibleForTesting
  static void setLocalAuthForTesting(LocalAuthentication auth) {
    _localAuth = auth;
    _isInitialized = true;
  }

  /// Checks if biometric authentication is available on the device.
  static Future<bool> isBiometricAvailable() async {
    try {
      await _ensureInitialized();

      if (_localAuth == null) {
        return false;
      }

      final bool isDeviceSupported = await _localAuth!.isDeviceSupported();

      if (!isDeviceSupported) {
        return false;
      }

      final bool canCheckBiometrics = await _localAuth!.canCheckBiometrics;

      return canCheckBiometrics;
    } on PlatformException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      await _ensureInitialized();
      if (_localAuth == null) return [];

      return await _localAuth!.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Authenticates the user using biometrics.
  /// [reason] is the message displayed to the user in the system dialog.
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access the app',
  }) async {
    try {
      await _ensureInitialized();
      if (_localAuth == null) {
        return false;
      }

      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final bool didAuthenticate = await _localAuth!.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
          break;
        case 'NotEnrolled':
          break;
        case 'LockedOut':
          break;
        case 'PermanentlyLockedOut':
          break;
        default:
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.weak:
        return 'PIN/Pattern';
      case BiometricType.strong:
        return 'Strong Biometric';
    }
  }

  static Future<List<String>> getAvailableBiometricNames() async {
    final types = await getAvailableBiometrics();
    return types.map((type) => getBiometricTypeName(type)).toList();
  }

  static Future<bool> shouldPromptBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return false;
      }

      final isAvailable = await isBiometricAvailable();
      return isAvailable;
    } catch (e) {
      return false;
    }
  }

  static String getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometric credentials enrolled. Please set up biometric authentication in your device settings';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Please use your device password';
      case 'PasscodeNotSet':
        return 'Please set up a device passcode first';
      case 'OtherOperatingSystem':
        return 'Biometric authentication is not supported on this platform';
      default:
        return 'Biometric authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  static Future<void> initialize() async {
    try {
      await _ensureInitialized();

      await _localAuth?.isDeviceSupported();
    } catch (e) {}
  }
}
