/// Service for tracking biometric-related operation contexts and grace periods.
class BiometricContextService {
  static final BiometricContextService _instance =
      BiometricContextService._internal();

  factory BiometricContextService() => _instance;

  BiometricContextService._internal();

  bool _isAccountOperation = false;
  DateTime? _lastAccountOperationTime;
  final List<String> _activeOperations = [];
  static const Duration _accountOperationGracePeriod = Duration(seconds: 3);

  bool get isAccountOperation => _isAccountOperation;

  /// List of currently active biometric-protected operations.
  List<String> get activeOperations => List.unmodifiable(_activeOperations);

  /// Returns true if biometric prompt should be skipped due to an active operation or grace period.
  bool get shouldSkipBiometric {
    if (_isAccountOperation) {
      return true;
    }

    if (_lastAccountOperationTime != null) {
      final timeSinceOperation = DateTime.now().difference(
        _lastAccountOperationTime!,
      );
      if (timeSinceOperation < _accountOperationGracePeriod) {
        return true;
      }
    }

    return false;
  }

  /// Marks the start of a biometric-protected [operation].
  void startAccountOperation(String operation) {
    _activeOperations.add(operation);
    _isAccountOperation = true;
    _lastAccountOperationTime = DateTime.now();
  }

  void endAccountOperation(String operation) {
    _activeOperations.remove(operation);
    _isAccountOperation = _activeOperations.isNotEmpty;
    _lastAccountOperationTime = DateTime.now();
  }

  void reset() {
    _isAccountOperation = false;
    _lastAccountOperationTime = null;
    _activeOperations.clear();
  }
}
