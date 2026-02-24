import 'package:flutter/foundation.dart';
import '../services/inventory_service.dart';

class StockLocationProvider extends ChangeNotifier {
  final InventoryService _service;

  StockLocationProvider({InventoryService? service}) : _service = service ?? InventoryService();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _quants = [];

  bool get isLoading => _loading;
  String? get error => _error;
  List<Map<String, dynamic>> get quants => _quants;

  double get totalOnHand => _quants.fold<double>(0.0, (sum, q) => sum + _toDouble(q['available_quantity'] ?? q['quantity']));
  double get totalReserved => _quants.fold<double>(0.0, (sum, q) => sum + _toDouble(q['reserved_quantity']));

  Future<void> loadForProduct(int productId) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service.fetchQuantsForProduct(productId);
      _quants = data;
    } catch (e) {
      _error = e.toString();
      _quants = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
