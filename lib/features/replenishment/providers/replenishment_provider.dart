import 'package:flutter/material.dart';
import '../models/replenishment_orderpoint.dart';
import '../services/replenishment_service.dart';

class ReplenishmentProvider with ChangeNotifier {
  final ReplenishmentService _service = ReplenishmentService();

  final int _pageSize = 80;
  int _currentPage = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _notSnoozed = true;
  String _trigger = 'manual';
  int _totalCount = 0;
  String? _error;
  String?
  _selectedGroupBy;
  bool _hasLoadedOnce = false;

  List<ReplenishmentOrderpoint> _items = [];

  List<ReplenishmentOrderpoint> get items => _items;

  bool get isLoading => _isLoading;

  String? get error => _error;

  int get totalCount => _totalCount;

  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalCount;

  bool get canGoToPreviousPage => _currentPage > 0;

  int get currentStartIndex => (_currentPage * _pageSize) + 1;

  int get currentEndIndex => (_currentPage + 1) * _pageSize > _totalCount
      ? _totalCount
      : (_currentPage + 1) * _pageSize;

  String? get selectedGroupBy => _selectedGroupBy;

  bool get isGrouped => _selectedGroupBy != null;

  bool get notSnoozed => _notSnoozed;

  String get trigger => _trigger;

  bool get hasLoadedOnce => _hasLoadedOnce;

  void setloading() {
    _isLoading = true;
  }

  String getPaginationText() {
    if (_totalCount == 0 && _items.isEmpty) return '0 items';
    if (_totalCount == 0) return '${_items.length} items';
    return '${currentStartIndex}-${currentEndIndex}/$_totalCount';
  }

  Future<void> fetch({
    String? searchQuery,
    bool? notSnoozed,
    String? trigger,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (searchQuery != null) _searchQuery = searchQuery;
    if (notSnoozed != null) _notSnoozed = notSnoozed;
    if (trigger != null) _trigger = trigger;
    _currentPage = 0;
    notifyListeners();

    try {
      final list = await _service.fetchOrderpoints(
        searchQuery: _searchQuery,
        notSnoozed: _notSnoozed,
        trigger: _trigger,
        limit: _pageSize,
        offset: 0,
      );
      final count = await _service.getCount(
        searchQuery: _searchQuery,
        notSnoozed: _notSnoozed,
        trigger: _trigger,
      );
      _items = list;
      _totalCount = count;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> goToNextPage() async {
    if (!canGoToNextPage || _isLoading) return;
    _isLoading = true;
    _items = [];
    _error = null;
    _currentPage++;
    notifyListeners();
    try {
      final list = await _service.fetchOrderpoints(
        searchQuery: _searchQuery,
        notSnoozed: _notSnoozed,
        trigger: _trigger,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      _items = list;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> goToPreviousPage() async {
    if (!canGoToPreviousPage || _isLoading) return;
    _isLoading = true;
    _items = [];
    _error = null;
    _currentPage--;
    notifyListeners();
    try {
      final list = await _service.fetchOrderpoints(
        searchQuery: _searchQuery,
        notSnoozed: _notSnoozed,
        trigger: _trigger,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      _items = list;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _notSnoozed = true;
    _trigger = 'manual';
    _selectedGroupBy = null;
    notifyListeners();
  }

  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    notifyListeners();
  }

  void applyFilters({
    String? search,
    bool? notSnoozed,
    String? trigger,
    String? groupBy,
  }) {
    _searchQuery = search ?? _searchQuery;
    if (notSnoozed != null) _notSnoozed = notSnoozed;
    if (trigger != null) _trigger = trigger;
    _selectedGroupBy = groupBy;
    fetch();
  }

  Future<void> actionReplenish({
    required List<int> ids,
    String trigger = 'manual',
  }) async {
    await _service.actionReplenish(ids: ids, trigger: trigger);
  }

  Future<void> actionReplenishAuto({
    required List<int> ids,
    String trigger = 'manual',
  }) async {
    await _service.actionReplenishAuto(ids: ids, trigger: trigger);
  }

  Future<void> snoozeOrderpoints({
    required List<int> ids,
    required String predefinedDate,
    DateTime? customDate,
  }) async {
    await _service.snoozeOrderpoints(
      ids: ids,
      predefinedDate: predefinedDate,
      customDate: customDate,
    );
  }

  Future<void> updateOrderpointValues({
    required int id,
    double? minQty,
    double? maxQty,
    double? manualToOrderQty,
    bool refreshAfter = true,
  }) async {
    await _service.updateOrderpointValues(
      id: id,
      minQty: minQty,
      maxQty: maxQty,
      manualToOrderQty: manualToOrderQty,
    );
    if (refreshAfter) {
      await fetch(
        searchQuery: _searchQuery,
        notSnoozed: _notSnoozed,
        trigger: _trigger,
      );
    }
  }

  Future<void> updateMinQty({required int id, required double minQty}) async {
    await updateOrderpointValues(id: id, minQty: minQty);
  }

  Future<void> updateMaxQty({required int id, required double maxQty}) async {
    await updateOrderpointValues(id: id, maxQty: maxQty);
  }

  Future<void> updateManualToOrderQty({
    required int id,
    required double qty,
  }) async {
    await updateOrderpointValues(id: id, manualToOrderQty: qty);
  }
}
