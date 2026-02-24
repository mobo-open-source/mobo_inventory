import 'package:flutter/material.dart';
import '../services/warehouse_service.dart';

class WarehouseDetailProvider with ChangeNotifier {
  final WarehouseService _service = WarehouseService();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _detail;
  bool _isOffline = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get detail => _detail;
  bool get isOffline => _isOffline;

  String get name => (_detail?['name'] ?? _detail?['display_name'] ?? '').toString();
  String get code => (_detail?['code'] ?? '').toString();
  String get companyName {
    final c = _detail?['company_id'];
    if (c is List && c.length > 1) return c[1].toString();
    if (c is Map) return (c['display_name'] ?? c['name'] ?? '').toString();
    return '';
  }

  String get partnerName {
    final p = _detail?['partner_id'];
    if (p is List && p.length > 1) return p[1].toString();
    if (p is Map) return (p['display_name'] ?? p['name'] ?? '').toString();
    return '';
  }

  Future<void> load(int id) async {
    _isLoading = true;
    _error = null;
    _isOffline = false;
    notifyListeners();

    try {
      final cached = await _service.loadCachedWarehouseDetail(id);
      if (cached != null) {
        _detail = cached;

        notifyListeners();
      }
    } catch (_) {}

    try {
      final fresh = await _service.fetchWarehouseDetail(id);
      if (fresh != null) {
        _detail = fresh;
        await _service.cacheWarehouseDetail(id, fresh);
        _isOffline = false;
      }
    } catch (e) {

      if (_detail != null) {
        _isOffline = true;
      } else {
        _error = 'Failed to load warehouse: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _service.fetchWarehouseDetail(id);
      if (fresh != null) {
        _detail = fresh;
        await _service.cacheWarehouseDetail(id, fresh);
        _isOffline = false;
      }
    } catch (e) {
      _isOffline = true;
      _error = 'Unable to refresh. Showing cached data if available.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
