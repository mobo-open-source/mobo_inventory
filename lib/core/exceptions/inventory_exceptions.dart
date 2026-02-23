abstract class InventoryException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const InventoryException(this.message, {this.code, this.details});

  @override
  String toString() => 'InventoryException: $message';
}

class NetworkException extends InventoryException {
  final NetworkErrorType type;

  const NetworkException(
    String message,
    this.type, {
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() =>
      'NetworkException(${type.toString().split('.').last}): $message';
}

enum NetworkErrorType {
  connectionTimeout,
  serverUnavailable,
  noConnection,
  authenticationFailed,
  rateLimited,
  unknown,
}

class ValidationException extends InventoryException {
  final String? field;
  final String userMessage;

  const ValidationException(
    String message,
    this.userMessage, {
    this.field,
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() =>
      'ValidationException${field != null ? '($field)' : ''}: $userMessage';
}

class SyncException extends InventoryException {
  final SyncErrorType type;

  const SyncException(
    String message,
    this.type, {
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() =>
      'SyncException(${type.toString().split('.').last}): $message';
}

enum SyncErrorType {
  statusConflict,
  concurrentModification,
  dataInconsistency,
  versionMismatch,
  unknown,
}

class OdooApiException extends InventoryException {
  final int statusCode;
  final String? endpoint;

  const OdooApiException(
    String message,
    this.statusCode, {
    this.endpoint,
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() =>
      'OdooApiException($statusCode${endpoint != null ? ' - $endpoint' : ''}): $message';
}

class BusinessRuleException extends InventoryException {
  final String rule;

  const BusinessRuleException(
    String message,
    this.rule, {
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() => 'BusinessRuleException($rule): $message';
}

class PermissionException extends InventoryException {
  final String operation;

  const PermissionException(
    String message,
    this.operation, {
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() => 'PermissionException($operation): $message';
}

class DataNotFoundException extends InventoryException {
  final String resourceType;
  final int? resourceId;

  const DataNotFoundException(
    String message,
    this.resourceType, {
    this.resourceId,
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);

  @override
  String toString() =>
      'DataNotFoundException($resourceType${resourceId != null ? ' #$resourceId' : ''}): $message';
}
