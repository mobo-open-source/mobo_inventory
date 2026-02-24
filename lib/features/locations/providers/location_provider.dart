import 'package:flutter/material.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _service = LocationService();

  List<StockLocation> _locations = [];
  bool _isLoading = false;
  String? _error;

  static const int _pageSize = 30;
  int _currentPage = 0;
  int _totalCount = 0;

  String _searchQuery = '';
  String _usage = 'internal';
  int?
  _parentId;
  String? _groupBy;

  List<StockLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String get usage => _usage;
  int? get parentId => _parentId;
  String? get selectedGroupBy => _groupBy;

  String getPaginationText() {
    if (_totalCount == 0 && _locations.isEmpty) return '0 items';
    if (_totalCount == 0) return '${_locations.length} items';
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize > _totalCount)
        ? _totalCount
        : (_currentPage + 1) * _pageSize;
    return '$start-$end/$_totalCount';
  }

  bool get canGoToPreviousPage => _currentPage > 0;
  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalCount;

  Future<void> loadCached() async {
    try {
      final cached = await _service.loadCachedLocations(parentId: _parentId);
      if (cached.isNotEmpty) {
        _locations = cached;
        _totalCount = cached.length;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
          }
  }

  Future<void> fetchLocations({
    String? searchQuery,
    String? usage,
    int? parentId,
    bool forceRefresh = false,
  }) async {

    if (!forceRefresh &&
        _locations.isEmpty &&
        (searchQuery == null || searchQuery.isEmpty) &&
        (usage == null || usage.isEmpty || usage == _usage)) {
      await loadCached();
    }

    if (_isLoading && !forceRefresh) return;

    if (usage != null) _usage = usage;
    _parentId = parentId ?? _parentId;
    _searchQuery = searchQuery ?? _searchQuery;

    _isLoading = true;
    _error = null;
    _currentPage = 0;

    if (forceRefresh) {
      _locations = [];
      _totalCount = 0;
      notifyListeners();
    } else {
      notifyListeners();
    }

    try {
      final items = await _service.fetchLocations(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        usage: _usage,
        parentId: _parentId,
        limit: _pageSize,
        offset: 0,
      );

      final count = await _service.getLocationsCount(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        usage: _usage,
        parentId: _parentId,
      );

      _locations = items;
      _totalCount = count;

      if (_searchQuery.isEmpty) {
        await _service.cacheLocations(items, parentId: _parentId);
      }
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _locations = [];
    _error = null;
    notifyListeners();
    try {
      final offset = _currentPage * _pageSize;
      final items = await _service.fetchLocations(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        usage: _usage,
        parentId: _parentId,
        limit: _pageSize,
        offset: offset,
      );
      _locations = items;
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await fetchLocations(forceRefresh: true);
  }

  Future<int> createLocation({
    required String name,
    String? usage,
    int? parentId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      final id = await _service.createLocation(
        name: name,
        usage: usage ?? _usage,
        parentId: parentId ?? _parentId,
      );
      await fetchLocations(forceRefresh: true);
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
    _locations = [];
    _isLoading = false;
    _error = null;
    _currentPage = 0;
    _totalCount = 0;
    _searchQuery = '';
    _usage = 'internal';
    _parentId = null;
    _groupBy = null;
    notifyListeners();
      }

  void clearFilters() {
    _searchQuery = '';
    _usage = 'internal';
    _parentId = null;
    _groupBy = null;
    _currentPage = 0;
    notifyListeners();
  }

  void setGroupBy(String? field) {
    _groupBy = field;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
