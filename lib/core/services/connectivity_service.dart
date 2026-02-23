import 'dart:async';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity and server reachability.
class ConnectivityService {
  ConnectivityService._();
  static ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  @visibleForTesting
  static void setInstanceForTesting(ConnectivityService service) {
    _instance = service;
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _internetController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _serverController =
      StreamController<bool>.broadcast();
  bool _lastInternetReachable = false;
  bool _lastServerReachable = true;
  String? _currentServerUrl;

  Stream<bool> get onInternetChanged => _internetController.stream;

  Stream<bool> get onServerChanged => _serverController.stream;

  /// Starts monitoring connectivity and server reachability.
  void startMonitoring() {
    _probeInternet();
    _probeServer();
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _probeInternet();
      await _probeServer();
    });
  }

  Future<void> _probeInternet() async {
    final reachable = await hasInternetAccess();
    if (reachable != _lastInternetReachable) {
      _lastInternetReachable = reachable;
      _internetController.add(reachable);
    }
  }

  Future<void> _probeServer() async {
    final url = _currentServerUrl;
    if (url == null) return;

    if (!_lastInternetReachable) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
      return;
    }
    try {
      await ensureServerReachable(url);
      if (_lastServerReachable != true) {
        _lastServerReachable = true;
        _serverController.add(true);
      }
    } catch (_) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
    }
  }

  /// Returns true if any network connection is available (Wi-Fi or Mobile).
  Future<bool> isNetworkAvailable() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Probes for actual internet access by performing a DNS lookup.
  Future<bool> hasInternetAccess({String host = 'example.com'}) async {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Throws [NoInternetException] if no internet access is detected.
  Future<void> ensureInternetOrThrow() async {
    final net = await isNetworkAvailable();
    if (!net) {
      throw NoInternetException(
        'No network connection. Please check Wi‑Fi or mobile data.',
      );
    }
    final online = await hasInternetAccess();
    if (!online) {
      throw NoInternetException(
        'Connected to a network but no internet access.',
      );
    }
  }

  /// Throws [ServerUnreachableException] if the [serverUrl] is not reachable.
  Future<void> ensureServerReachable(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final host = uri.host.isNotEmpty ? uri.host : serverUrl;
      final res = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      if (res.isEmpty) {
        throw ServerUnreachableException('Unable to reach server host: $host');
      }
    } on Exception {
      throw ServerUnreachableException(
        'Unable to reach server. Please verify the URL and network.',
      );
    }
  }

  void setCurrentServerUrl(String? serverUrl) {
    _currentServerUrl = serverUrl;

    _probeServer();
  }

  bool get lastKnownServerReachable =>
      _currentServerUrl == null ? true : _lastServerReachable;
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
  @override
  String toString() => 'NoInternetException: $message';
}

class ServerUnreachableException implements Exception {
  final String message;
  ServerUnreachableException(this.message);
  @override
  String toString() => 'ServerUnreachableException: $message';
}
