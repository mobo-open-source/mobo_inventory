import 'package:flutter/material.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../models/picking_model.dart';
import '../services/picking_service.dart';

class PickingProvider extends ChangeNotifier {
  final PickingService _service;
  final String pickingTypeCode;

  /// The Status filter the list opens with, e.g.
  /// [PickingService.toProcessStates] for a dashboard card's list, so the
  /// list's total is the number the card showed. The user can still change
  /// or clear it.
  final List<String> initialStates;

  /// Names this list's offline cache; defaults to [pickingTypeCode]. Two
  /// lists of one operation type (PoS Orders, Delivery Orders) need their
  /// own.
  final String cacheName;

  PickingProvider({
    required this.pickingTypeCode,
    this.initialStates = const [],
    PickingService? service,
    String? cacheName,
  }) : _service = service ?? PickingService(),
       cacheName = cacheName ?? pickingTypeCode,
       _states = List<String>.of(initialStates);

  bool _isLoading = false;
  String? _error;
  List<Picking> _items = [];
  int _totalCount = 0;
  bool _hasLoadedOnce = false;

  int _currentPage = 0;
  final int _pageSize = 20;

  String _searchQuery = '';
  List<String> _states;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;

  Map<String, int> _groupSummary = {};
  final Map<String, List<Picking>> _loadedGroups = {};
  // Group label -> the Odoo domain that selects that group's pickings.
  final Map<String, List<dynamic>> _groupDomains = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Picking> get items => _items;
  int get totalCount => _totalCount;
  int get pageSize => _pageSize;
  int get currentPage => _currentPage;
  bool get canGoToPreviousPage => _currentPage > 0;
  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalCount;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String getPaginationText() {
    if (_totalCount == 0 && _items.isEmpty) return '0 items';
    if (_totalCount == 0) return '${_items.length} items';
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize > _totalCount)
        ? _totalCount
        : (_currentPage + 1) * _pageSize;
    return '$start-$end/$_totalCount';
  }

  String get searchQuery => _searchQuery;
  List<String> get states => _states;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedGroupBy => _selectedGroupBy;
  Map<String, int> get groupSummary => _groupSummary;
  Map<String, List<Picking>> get loadedGroups => _loadedGroups;

  /// The offline cache holds only the list's default view (no search or
  /// dates, Status filter as opened). A list that opens filtered keeps its
  /// own cache, so it never flashes the unfiltered rows — and their count —
  /// before the real fetch lands.
  String get _cacheScope => initialStates.isEmpty
      ? cacheName
      : '${cacheName}_${initialStates.join('_')}';

  bool _isInitialStates(List<String> states) =>
      states.length == initialStates.length &&
      states.toSet().containsAll(initialStates);

  bool get _isDefaultView =>
      _searchQuery.isEmpty &&
      _startDate == null &&
      _endDate == null &&
      _isInitialStates(_states);

  Future<void> loadCachedPickings() async {
    try {
      final cached = await _service.loadCachedPickings(_cacheScope);
      if (cached.isNotEmpty) {
        _items = cached;
        _totalCount = cached.length;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> fetchPickings({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _items = [];
      _isLoading = false;
      _totalCount = 0;
      _currentPage = 0;
      notifyListeners();
    }

    if (!forceRefresh &&
        _items.isEmpty &&
        (searchQuery ?? _searchQuery).isEmpty &&
        _isInitialStates(states ?? _states) &&
        startDate == null &&
        endDate == null) {
      await loadCachedPickings();
    }

    if (_isLoading) return;

    _searchQuery = searchQuery ?? _searchQuery;
    if (states != null) _states = states;
    _startDate = startDate;
    _endDate = endDate;

    _isLoading = true;
    _error = null;
    _currentPage = 0;
    notifyListeners();

    try {
      final items = await _service.fetchPickings(
        pickingTypeCode: pickingTypeCode,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _states.isEmpty ? null : _states,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: 0,
      );
      final count = await _service.getPickingCount(
        pickingTypeCode: pickingTypeCode,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _states.isEmpty ? null : _states,
        startDate: _startDate,
        endDate: _endDate,
      );

      _items = items;
      _totalCount = count;

      if (_isDefaultView) {
        await _service.cachePickings(_cacheScope, items);
      }
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> goToNextPage() async {
    if (!canGoToNextPage || _isLoading) return;
    _currentPage++;
    await _fetchSpecificPage();
  }

  Future<void> goToPreviousPage() async {
    if (!canGoToPreviousPage || _isLoading) return;
    _currentPage--;
    await _fetchSpecificPage();
  }

  Future<void> _fetchSpecificPage() async {
    _isLoading = true;
    _items = [];
    _error = null;
    notifyListeners();

    try {
      final items = await _service.fetchPickings(
        pickingTypeCode: pickingTypeCode,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _states.isEmpty ? null : _states,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      _items = items;
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _states = [];
    _startDate = null;
    _endDate = null;
    _selectedGroupBy = null;
    _groupSummary.clear();
    _groupDomains.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    if (groupBy == null) {
      _groupSummary.clear();
      _groupDomains.clear();
      _loadedGroups.clear();
    }
    notifyListeners();
  }

  Future<void> fetchGroupSummary() async {
    if (_selectedGroupBy == null) return;

    if (_groupSummary.isEmpty) {
      final cached = await _service.loadCachedGroupSummary(
        _cacheScope,
        _selectedGroupBy!,
      );
      if (cached.isNotEmpty) {
        _groupSummary = cached;
        notifyListeners();
      }
    }

    try {
      final domains = <String, List<dynamic>>{};
      final summary = await _service.fetchGroupSummary(
        domainsOut: domains,
        pickingTypeCode: pickingTypeCode,
        groupByField: _selectedGroupBy!,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _states.isEmpty ? null : _states,
        startDate: _startDate,
        endDate: _endDate,
      );
      _groupSummary = summary;
      _groupDomains
        ..clear()
        ..addAll(domains);
      _loadedGroups.clear();

      if (_isDefaultView) {
        await _service.cacheGroupSummary(
          _cacheScope,
          _selectedGroupBy!,
          summary,
        );
      }

      notifyListeners();
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  Future<void> loadGroupPickings(String groupKey) async {
    if (_loadedGroups.containsKey(groupKey)) return;
    try {
      // Groups shown from the offline cache carry no domain yet.
      if (!_groupDomains.containsKey(groupKey)) await fetchGroupSummary();
      final domain = _groupDomains[groupKey];
      // Without the group's domain there is nothing correct to show: the old
      // fallback filtered only Status groups, so every Priority or Date group
      // listed the same pickings.
      if (domain == null) return;

      final items = await _service.fetchPickings(
        pickingTypeCode: pickingTypeCode,
        domainOverride: domain,
        limit: 100,
        offset: 0,
      );
      _loadedGroups[groupKey] = items;
      notifyListeners();
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  void resetState() {
    _isLoading = false;
    _error = null;
    _items = [];
    _totalCount = 0;
    _currentPage = 0;
    _searchQuery = '';
    _states = List<String>.of(initialStates);
    _startDate = null;
    _endDate = null;
    _selectedGroupBy = null;
    _groupSummary.clear();
    _groupDomains.clear();
    _loadedGroups.clear();
    notifyListeners();
  }
}
