import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/widgets/snackbars/custom_snackbar.dart';
import 'connectivity_service.dart';
import '../exceptions/app_exceptions.dart';
import '../exceptions/odoo_error_mapper.dart';

class OfflineErrorHandler {
  OfflineErrorHandler._();
  static final OfflineErrorHandler instance = OfflineErrorHandler._();

  StreamSubscription<bool>? _internetSubscription;
  StreamSubscription<bool>? _serverSubscription;
  BuildContext? _lastContext;
  bool _hasShownOfflineSnackbar = false;
  bool _hasShownServerUnreachableSnackbar = false;

  void initialize(BuildContext context) {
    _lastContext = context;
    _startMonitoring();
  }

  void updateContext(BuildContext context) {
    _lastContext = context;
  }

  void _startMonitoring() {

    _internetSubscription?.cancel();
    _internetSubscription = ConnectivityService.instance.onInternetChanged
        .listen((isOnline) {
          if (!isOnline && !_hasShownOfflineSnackbar) {
            _hasShownOfflineSnackbar = true;
            _hasShownServerUnreachableSnackbar = false;
            _showOfflineSnackbar();
          } else if (isOnline && _hasShownOfflineSnackbar) {
            _hasShownOfflineSnackbar = false;
            _showBackOnlineSnackbar();
          }
        });

    _serverSubscription?.cancel();
    _serverSubscription = ConnectivityService.instance.onServerChanged.listen((
      isReachable,
    ) {
      if (!isReachable &&
          !_hasShownServerUnreachableSnackbar &&
          !_hasShownOfflineSnackbar) {
        _hasShownServerUnreachableSnackbar = true;
        _showServerUnreachableSnackbar();
      } else if (isReachable && _hasShownServerUnreachableSnackbar) {
        _hasShownServerUnreachableSnackbar = false;
        _showServerReconnectedSnackbar();
      }
    });
  }

  void _showOfflineSnackbar() {
    if (_lastContext != null && _lastContext!.mounted) {
      CustomSnackbar.showOffline(_lastContext!);
    }
  }

  void _showBackOnlineSnackbar() {
    if (_lastContext != null && _lastContext!.mounted) {
      CustomSnackbar.showInfo(_lastContext!, 'Back online');
    }
  }

  void _showServerUnreachableSnackbar() {
    if (_lastContext != null && _lastContext!.mounted) {
      CustomSnackbar.showServerUnreachable(_lastContext!);
    }
  }

  void _showServerReconnectedSnackbar() {
    if (_lastContext != null && _lastContext!.mounted) {
      CustomSnackbar.showSuccess(_lastContext!, 'Server connection restored');
    }
  }

  String handleError(
    BuildContext context,
    Object error, {
    String? fallbackMessage,
  }) {
    final message = _classifyError(error, fallbackMessage);

    if (error is NoInternetException) {
      CustomSnackbar.showOffline(context);
    } else if (error is ServerUnreachableException) {
      CustomSnackbar.showServerUnreachable(context);
    } else if (error is NetworkException) {
      CustomSnackbar.showNetworkError(context, message);
    } else if (error is AuthException) {
      CustomSnackbar.showError(context, message);
    } else {
      CustomSnackbar.showError(context, message);
    }

    return message;
  }

  String _classifyError(Object error, String? fallbackMessage) {

    if (error is NoInternetException) {
      return error.message;
    }
    if (error is ServerUnreachableException) {
      return error.message;
    }
    if (error is NetworkException) {
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }

    final odooMessage = OdooErrorMapper.toUserMessage(error);
    if (odooMessage !=
        'Unexpected server error. Please try again or contact support.') {
      return odooMessage;
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }

    if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL certificate error. Please contact your administrator.';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Authentication failed. Please log in again.';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'Access denied. You don\'t have permission to perform this action.';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Resource not found. Please contact your administrator.';
    }

    if (errorStr.contains('500') ||
        errorStr.contains('internal server error')) {
      return 'Server error occurred. Please try again later.';
    }

    return fallbackMessage ?? 'An unexpected error occurred. Please try again.';
  }

  Future<T?> executeWithErrorHandling<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? errorMessage,
    bool showSnackbar = true,
    VoidCallback? onRetry,
  }) async {
    try {
      return await operation();
    } catch (e) {
      
      if (showSnackbar) {
        final message = handleError(context, e, fallbackMessage: errorMessage);

        if (onRetry != null && _isConnectivityError(e)) {
          CustomSnackbar.show(
            context: context,
            title: 'Error',
            message: message,
            type: SnackbarType.error,
            duration: const Duration(seconds: 6),
          );
        }
      }

      return null;
    }
  }

  bool _isConnectivityError(Object error) {
    return error is NoInternetException ||
        error is ServerUnreachableException ||
        error is NetworkException ||
        error.toString().toLowerCase().contains('socketexception') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('timeout');
  }

  Future<T?> retryOperation<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        attempt++;

        final hasInternet = await ConnectivityService.instance
            .hasInternetAccess();
        if (!hasInternet) {
                    throw NoInternetException('No internet connection available');
        }

        return await operation();
      } catch (e) {
        
        if (attempt >= maxAttempts) {
          rethrow;
        }

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }

    return null;
  }

  void dispose() {
    _internetSubscription?.cancel();
    _serverSubscription?.cancel();
    _internetSubscription = null;
    _serverSubscription = null;
    _lastContext = null;
  }
}
