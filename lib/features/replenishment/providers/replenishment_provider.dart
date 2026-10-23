import 'package:flutter/material.dart';
import '../models/replenishment_orderpoint.dart';
import '../services/replenishment_service.dart';

class ReplenishmentProvider with ChangeNotifier {
  final ReplenishmentService _service = ReplenishmentService();

  // Odoo's own Replenishment defaults: manual rules that still need
  // ordering, snoozed ones hidden.
  static const String _defaultTrigger = 'manual';
  static const bool _defaultToReorder = true;

  /// Rows loaded for one expanded group; larger groups show a note.
  static const int groupPageSize = 200;

  final int _pageSize = 80;
  int _currentPage = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _notSnoozed = true;
  bool _toReorder = _defaultToReorder;
  String _trigger = _defaultTrigger;
  int _totalCount = 0;
  String? _error;
  String? _selectedGroupBy;
  bool _hasLoadedOnce = false;

  // Each list load gets a new id; a response that comes back after a newer
  // load started is dropped, so typing during a load never shows stale rows
  // (the old guard simply ignored the newer search).
  int _requestId = 0;

  List<ReplenishmentOrderpoint> _items = [];
  List<ReplenishmentGroup> _groups = [];
  final Map<String, List<ReplenishmentOrderpoint>> _groupItems = {};
  final Set<String> _loadingGroups = {};
  final Set<String> _failedGroups = {};

  List<ReplenishmentOrderpoint> get items => _items;

  List<ReplenishmentGroup> get groups => _groups;

  List<ReplenishmentOrderpoint>? itemsForGroup(String key) => _groupItems[key];

  bool isGroupLoading(String key) => _loadingGroups.contains(key);

  /// A group whose rows failed to load; it is not retried until asked.
  bool isGroupFailed(String key) => _failedGroups.contains(key);

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

  bool get toReorder => _toReorder;

  String get trigger => _trigger;

  String get searchQuery => _searchQuery;

  bool get hasLoadedOnce => _hasLoadedOnce;

  /// True when nothing at all is loaded for the current mode.
  bool get isEmpty => isGrouped ? _groups.isEmpty : _items.isEmpty;

  /// Filters narrowing the list (search and group-by not included).
  int get activeFilterCount {
    int count = 0;
    if (!_notSnoozed) count++;
    if (_toReorder) count++;
    if (_trigger.isNotEmpty) count++;
    return count;
  }

  List<dynamic> get _domain => _service.buildDomain(
    searchQuery: _searchQuery,
    notSnoozed: _notSnoozed,
    toReorder: _toReorder,
    trigger: _trigger,
  );

  String getPaginationText() {
    if (_totalCount == 0 && _items.isEmpty) return '0 items';
    if (_totalCount == 0) return '${_items.length} items';
    return '$currentStartIndex-$currentEndIndex/$_totalCount';
  }

  /// Reloads from the first page (or the group summary when grouped).
  /// Parameters left null keep their current value.
  Future<void> fetch({
    String? searchQuery,
    bool? notSnoozed,
    bool? toReorder,
    String? trigger,
    bool forceRefresh = false,
  }) async {
    if (searchQuery != null) _searchQuery = searchQuery;
    if (notSnoozed != null) _notSnoozed = notSnoozed;
    if (toReorder != null) _toReorder = toReorder;
    if (trigger != null) _trigger = trigger;
    _currentPage = 0;
    if (isGrouped) {
      await _loadGroups();
    } else {
      await _loadPage(withCount: true);
    }
  }

  Future<void> _loadPage({bool withCount = false}) async {
    final requestId = ++_requestId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final domain = _domain;
      final results = await Future.wait([
        _service.fetchOrderpoints(
          domain: domain,
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        ),
        if (withCount) _service.getCount(domain: domain),
      ]);
      if (requestId != _requestId) return;
      _items = results[0] as List<ReplenishmentOrderpoint>;
      if (withCount) _totalCount = results[1] as int;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = e.toString();
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        _hasLoadedOnce = true;
        notifyListeners();
      }
    }
  }

  /// Loads the group summary, then reloads every group that was open, so an
  /// order or edit refreshes the rows the user is looking at.
  Future<void> _loadGroups() async {
    final requestId = ++_requestId;
    final openKeys = _groupItems.keys.toSet();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final groups = await _service.fetchGroups(
        domain: _domain,
        groupByField: _selectedGroupBy!,
      );
      if (requestId != _requestId) return;
      _groups = groups;
      _totalCount = groups.fold(0, (sum, g) => sum + g.count);
      _groupItems.clear();
      _loadingGroups.clear();
      _failedGroups.clear();
    } catch (e) {
      if (requestId != _requestId) return;
      _error = e.toString();
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        _hasLoadedOnce = true;
        notifyListeners();
      }
    }

    if (requestId != _requestId) return;
    for (final g in _groups) {
      if (openKeys.contains(g.key)) loadGroup(g.key);
    }
  }

  /// Fetches the rows of one group the first time it is expanded.
  Future<void> loadGroup(String key, {bool force = false}) async {
    if (_loadingGroups.contains(key)) return;
    if (!force && _groupItems.containsKey(key)) return;
    final group = _groups.where((g) => g.key == key).firstOrNull;
    if (group == null || _selectedGroupBy == null) return;

    final requestId = _requestId;
    _loadingGroups.add(key);
    _failedGroups.remove(key);
    notifyListeners();
    try {
      final items = await _service.fetchOrderpoints(
        domain: [
          ..._domain,
          [_selectedGroupBy, '=', group.value],
        ],
        limit: groupPageSize,
      );
      if (requestId != _requestId) return;
      _groupItems[key] = items;
    } catch (_) {
      if (requestId != _requestId) return;
      _failedGroups.add(key);
    } finally {
      if (requestId == _requestId) {
        _loadingGroups.remove(key);
        notifyListeners();
      }
    }
  }

  Future<void> goToNextPage() async {
    if (!canGoToNextPage || _isLoading) return;
    _currentPage++;
    _items = [];
    await _loadPage();
  }

  Future<void> goToPreviousPage() async {
    if (!canGoToPreviousPage || _isLoading) return;
    _currentPage--;
    _items = [];
    await _loadPage();
  }

  /// Removes every filter, so all replenishment rules are listed.
  void clearFilters() {
    _searchQuery = '';
    _notSnoozed = true;
    _toReorder = false;
    _trigger = '';
    _setGroupBy(null);
    notifyListeners();
  }

  /// Drops everything loaded for the outgoing account — list, counts, paging
  /// and filters — so the next screen visit fetches for the account now
  /// signed in.
  void resetState() {
    _requestId++;
    _items = [];
    _currentPage = 0;
    _totalCount = 0;
    _isLoading = false;
    _hasLoadedOnce = false;
    _error = null;
    _searchQuery = '';
    _notSnoozed = true;
    _toReorder = _defaultToReorder;
    _trigger = _defaultTrigger;
    _setGroupBy(null);
    notifyListeners();
  }

  void _setGroupBy(String? groupBy) {
    if (groupBy != _selectedGroupBy) {
      _groups = [];
      _groupItems.clear();
      _loadingGroups.clear();
      _failedGroups.clear();
    }
    _selectedGroupBy = groupBy;
  }

  void setGroupBy(String? groupBy) {
    _setGroupBy(groupBy);
    notifyListeners();
  }

  void applyFilters({
    String? search,
    bool? notSnoozed,
    bool? toReorder,
    String? trigger,
    String? groupBy,
  }) {
    _searchQuery = search ?? _searchQuery;
    if (notSnoozed != null) _notSnoozed = notSnoozed;
    if (toReorder != null) _toReorder = toReorder;
    if (trigger != null) _trigger = trigger;
    _setGroupBy(groupBy);
    fetch();
  }

  /// Returns the name of the order Odoo generated, when it reports one.
  Future<String?> actionReplenish({required List<int> ids}) =>
      _service.actionReplenish(ids: ids);

  /// Returns the name of the order Odoo generated, when it reports one.
  Future<String?> actionReplenishAuto({required List<int> ids}) =>
      _service.actionReplenishAuto(ids: ids);

  /// Returns the date the orderpoints are snoozed until.
  Future<DateTime> snoozeOrderpoints({
    required List<int> ids,
    required String predefinedDate,
    DateTime? customDate,
  }) => _service.snoozeOrderpoints(
    ids: ids,
    predefinedDate: predefinedDate,
    customDate: customDate,
  );

  Future<List<Map<String, dynamic>>> fetchLocations({int? companyId}) =>
      _service.fetchLocations(companyId: companyId);

  Future<void> updateOrderpointValues({
    required int id,
    double? minQty,
    double? maxQty,
    double? manualToOrderQty,
    int? locationId,
    bool refreshAfter = true,
  }) async {
    await _service.updateOrderpointValues(
      id: id,
      minQty: minQty,
      maxQty: maxQty,
      manualToOrderQty: manualToOrderQty,
      locationId: locationId,
    );
    if (refreshAfter) await fetch();
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
