import 'package:flutter/material.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../models/warehouse_model.dart';
import '../services/warehouse_service.dart';

class WarehouseProvider with ChangeNotifier {
  final WarehouseService _service = WarehouseService();
  bool _isDisposed = false;

  List<Warehouse> _warehouses = [];
  bool _isLoading = false;
  String? _error;

  static const int _pageSize = 20;
  int _currentPage = 0;
  int _totalCount = 0;

  String _searchQuery = '';

  String? _selectedGroupBy;
  bool _filterHasStockLocation = false;
  bool _filterHasCode = false;

  List<Warehouse> get warehouses => _warehouses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String? get selectedGroupBy => _selectedGroupBy;
  bool get filterHasStockLocation => _filterHasStockLocation;
  bool get filterHasCode => _filterHasCode;

  String getPaginationText() {
    if (_totalCount == 0) return '0 items';
    final start = (_currentPage * _pageSize) + 1;
    final end = ((_currentPage + 1) * _pageSize) > _totalCount
        ? _totalCount
        : (_currentPage + 1) * _pageSize;
    return '$start-$end/$_totalCount';
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchCompanies() {
    return _service.fetchCompanies();
  }

  Future<Map<String, dynamic>?> fetchCompanyDetail(int companyId) {
    return _service.fetchCompanyDetail(companyId);
  }

  Future<int> getWarehouseCountByCompany(int companyId) {
    return _service.getWarehouseCountByCompany(companyId);
  }

  bool get canGoToPreviousPage => _currentPage > 0;
  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalCount;

  Future<void> loadCachedWarehouses() async {
    try {
      final cached = await _service.loadCachedWarehouses();
      if (cached.isNotEmpty) {
        _warehouses = cached;
        _totalCount = cached.length;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
          }
  }

  Future<void> fetchWarehouses({
    String? searchQuery,
    bool forceRefresh = false,
  }) async {

    if (!forceRefresh &&
        _warehouses.isEmpty &&
        (searchQuery == null || searchQuery.isEmpty)) {
      await loadCachedWarehouses();
    }

    if (_isLoading && !forceRefresh) return;

    _searchQuery = searchQuery ?? _searchQuery;
    _isLoading = true;
    _error = null;
    _currentPage = 0;

    if (forceRefresh) {
      _warehouses = [];
      _totalCount = 0;
      notifyListeners();
    } else {
      notifyListeners();
    }

    try {
      final warehouses = await _service.fetchWarehouses(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: 0,
        hasStockLocation: _filterHasStockLocation,
        hasCode: _filterHasCode,
      );

      final count = await _service.getWarehouseCount(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        hasStockLocation: _filterHasStockLocation,
        hasCode: _filterHasCode,
      );

      _warehouses = warehouses;
      _totalCount = count;

      if (_searchQuery.isEmpty) {
        await _service.cacheWarehouses(warehouses);
      }
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> goToNextPage() async {
    if (!canGoToNextPage || _isLoading) return;
    _currentPage++;
    await _fetchPage();
  }

  Future<void> goToPreviousPage() async {
    if (!canGoToPreviousPage || _isLoading) return;
    _currentPage--;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    _isLoading = true;
    _warehouses = [];
    _error = null;
    notifyListeners();

    try {
      final offset = _currentPage * _pageSize;
      final warehouses = await _service.fetchWarehouses(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: offset,
        hasStockLocation: _filterHasStockLocation,
        hasCode: _filterHasCode,
      );

      _warehouses = warehouses;
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await fetchWarehouses(forceRefresh: true);
  }

  Future<int> createWarehouse({
    required String name,
    required String code,
    required int companyId,
    int? partnerId,
    bool active = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      final id = await _service.createWarehouse(
        name: name,
        code: code,
        companyId: companyId,
        partnerId: partnerId,
        active: active,
      );
      await fetchWarehouses(forceRefresh: true);
      return id;
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetState() {
    _warehouses = [];
    _isLoading = false;
    _error = null;
    _currentPage = 0;
    _totalCount = 0;
    _searchQuery = '';
    _selectedGroupBy = null;
    _filterHasStockLocation = false;
    _filterHasCode = false;
    notifyListeners();
      }

  void clearFilters() {
    _searchQuery = '';
    _selectedGroupBy = null;
    _filterHasStockLocation = false;
    _filterHasCode = false;
    _currentPage = 0;
    notifyListeners();
  }

  void setGroupBy(String? value) {
    _selectedGroupBy = value;
    notifyListeners();
  }

  void setFilterHasStockLocation(bool value) {
    _filterHasStockLocation = value;
    notifyListeners();
  }

  void setFilterHasCode(bool value) {
    _filterHasCode = value;
    notifyListeners();
  }
}
