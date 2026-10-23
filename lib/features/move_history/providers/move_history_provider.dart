import 'package:flutter/foundation.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/services/odoo_metadata_service.dart';
import '../models/move_history_item.dart';
import '../services/move_history_service.dart';

class MoveHistoryProvider extends ChangeNotifier {
  final MoveHistoryService _service = MoveHistoryService();

  List<MoveHistoryItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasAutoRetriedInitialLoad = false;

  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  bool _hasLoadedOnce = false;

  /// Odoo's Moves History opens on its "Done" filter: only moves that have
  /// happened, not the Available/Draft ones still to be processed. Clearing
  /// the filter in the sheet shows every move, as removing that facet does
  /// in Odoo.
  static const String defaultStatus = 'done';

  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _status = defaultStatus;
  List<String> _pickingTypeCodes = [];
  bool _activeOnly = false;
  bool _inventoryOnly = false;

  String? _groupBy;
  final Map<String, String> _groupByOptions = {
    'product': 'Product',
    'state': 'Status',
    'location': 'Location (From → To)',
    'category': 'Category',
    'transfer': 'Transfer',
    'date:day': 'Date (Day)',
  };

  /// Group label → its move lines' count from the server, in Odoo's order.
  Map<String, int> _groupSummary = {};
  // Group label -> the Odoo domain that selects that group's move lines.
  final Map<String, List<dynamic>> _groupDomains = {};
  final Map<String, List<MoveHistoryItem>> _loadedGroups = {};

  /// Move lines a group loads at a time.
  static const int _groupPageSize = 80;

  Map<String, int> get groupSummary => _groupSummary;
  Map<String, List<MoveHistoryItem>> get loadedGroups => _loadedGroups;

  List<MoveHistoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _totalCount;
  bool get hasLoadedOnce => _hasLoadedOnce;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String get searchQuery => _searchQuery;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  String? get status => _status;
  List<String> get pickingTypeCodes => _pickingTypeCodes;
  bool get activeOnly => _activeOnly;
  bool get inventoryOnly => _inventoryOnly;
  String? get selectedGroupBy => _groupBy;
  Map<String, String> get groupByOptions => _groupByOptions;

  bool get canGoToPreviousPage => _currentPage > 1;
  bool get canGoToNextPage => (_currentPage * _pageSize) < _totalCount;

  String getPaginationText() {
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize).clamp(0, _totalCount);
    return "$start-$end/$_totalCount";
  }

  Future<void> fetchHistory({
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool? activeOnly,
    bool? inventoryOnly,
    String? groupBy,
    bool updateFilters = false,
    bool force = false,
  }) async {
    // Only the very first automatic load (not a manual pull-to-refresh, not
    // a filter change) gets a silent retry — cold-start requests can hit a
    // transient hiccup (session/client warm-up, brief connectivity blip)
    // that clears up moments later, which previously left the screen stuck
    // on an error/empty state until the user manually refreshed.
    final isInitialAutoLoad = !_hasLoadedOnce && !force && !updateFilters;

    try {
      if (_isLoading && !force && !updateFilters) return;
      _isLoading = true;
      _items = [];
      _error = null;

      if (force) {
        _totalCount = 0;
        notifyListeners();
      }

      if (updateFilters) {
        _searchQuery = searchQuery ?? '';
        _dateFrom = dateFrom;
        _dateTo = dateTo;
        _status = status;
        _pickingTypeCodes = pickingTypeCodes ?? _pickingTypeCodes;
        if (activeOnly != null) _activeOnly = activeOnly;
        if (inventoryOnly != null) _inventoryOnly = inventoryOnly;
        _groupBy = groupBy ?? _groupBy;
        _currentPage = 1;
      }

      notifyListeners();

      final hasMoveLine = await OdooMetadataService.hasModel('stock.move.line');
      if (!hasMoveLine) {
        _isLoading = false;
        _error = OdooErrorMapper.toUserMessage("KeyError: 'stock.move.line'");
        notifyListeners();
        return;
      }

      final offset = (_currentPage - 1) * _pageSize;

      final results = await Future.wait([
        _service.fetchHistory(
          offset: offset,
          limit: _pageSize,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          status: _status,
          pickingTypeCodes: _pickingTypeCodes.isEmpty
              ? null
              : _pickingTypeCodes,
          activeOnly: _activeOnly,
          inventoryOnly: _inventoryOnly,
        ),
        _service.getHistoryCount(
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          status: _status,
          pickingTypeCodes: _pickingTypeCodes.isEmpty
              ? null
              : _pickingTypeCodes,
          activeOnly: _activeOnly,
          inventoryOnly: _inventoryOnly,
        ),
      ]);

      _items = results[0] as List<MoveHistoryItem>;
      _totalCount = results[1] as int;
      if (_groupBy != null) await fetchGroupSummary();
    } catch (e) {
      _error = 'Failed to fetch history: ${OdooErrorMapper.toUserMessage(e)}';
    } finally {
      _isLoading = false;

      // A successful-but-empty first result is just as suspicious as an
      // outright error here: this call fires the moment the tab is opened,
      // which can race the session/company context still settling (e.g.
      // right after login or a company switch) — the query can legitimately
      // execute against a stale/incomplete context and come back with zero
      // rows even though real data exists, with no exception thrown at all.
      final looksSuspiciouslyEmpty =
          _error == null && _items.isEmpty && _totalCount == 0;
      // If this is about to be silently retried, keep hasLoadedOnce false
      // (and isLoading true below) so the screen keeps showing its loading
      // shimmer instead of flashing the error/empty state for the ~700ms
      // retry window.
      final willAutoRetry =
          isInitialAutoLoad &&
          !_hasAutoRetriedInitialLoad &&
          (_error != null || looksSuspiciouslyEmpty);
      _hasLoadedOnce = !willAutoRetry;
      if (willAutoRetry) _isLoading = true;
      notifyListeners();
    }

    if (isInitialAutoLoad &&
        !_hasAutoRetriedInitialLoad &&
        (_error != null || (_items.isEmpty && _totalCount == 0))) {
      _hasAutoRetriedInitialLoad = true;
      await Future.delayed(const Duration(milliseconds: 700));
      await fetchHistory(force: true);
    }
  }

  Future<void> refresh() async {
    _currentPage = 1;
    await fetchHistory(force: true);
  }

  Future<void> goToNextPage() async {
    if (canGoToNextPage && !_isLoading) {
      _currentPage++;
      await fetchHistory();
    }
  }

  Future<void> goToPreviousPage() async {
    if (canGoToPreviousPage && !_isLoading) {
      _currentPage--;
      await fetchHistory();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _dateFrom = null;
    _dateTo = null;
    _status = null;
    _pickingTypeCodes = [];
    _activeOnly = false;
    _inventoryOnly = false;
    _groupBy = null;
    _clearGroups();
    _currentPage = 1;
    notifyListeners();
  }

  void setGroupBy(String? field) {
    _groupBy = field;
    if (field == null) _clearGroups();
    notifyListeners();
  }

  void _clearGroups() {
    _groupSummary = {};
    _groupDomains.clear();
    _loadedGroups.clear();
  }

  /// Counts the move lines of each group on the server, under the current
  /// filters — every matching line, not just the page on screen.
  Future<void> fetchGroupSummary() async {
    final groupBy = _groupBy;
    if (groupBy == null) return;
    try {
      final domains = <String, List<dynamic>>{};
      final summary = await _service.fetchGroupSummary(
        groupBy: groupBy,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _status,
        pickingTypeCodes: _pickingTypeCodes.isEmpty ? null : _pickingTypeCodes,
        activeOnly: _activeOnly,
        inventoryOnly: _inventoryOnly,
        domainsOut: domains,
      );
      if (_groupBy != groupBy) return; // a newer group-by took over
      // Groups already open are reloaded under the new counts rather than
      // left loading.
      final reopen = _loadedGroups.keys.where(summary.containsKey).toList();
      _groupSummary = summary;
      _groupDomains
        ..clear()
        ..addAll(domains);
      _loadedGroups.clear();
      notifyListeners();
      for (final groupKey in reopen) {
        await loadGroupItems(groupKey);
      }
    } catch (_) {
      _clearGroups();
      notifyListeners();
    }
  }

  /// Loads the first move lines of [groupKey], by the group's own domain.
  Future<void> loadGroupItems(String groupKey) async {
    if (_loadedGroups.containsKey(groupKey)) return;
    final domain = _groupDomains[groupKey];
    if (domain == null) return;
    try {
      _loadedGroups[groupKey] = await _service.fetchHistory(
        domainOverride: domain,
        limit: _groupPageSize,
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Appends the next move lines of [groupKey] to those it shows.
  Future<void> loadMoreGroupItems(String groupKey) async {
    final loaded = _loadedGroups[groupKey];
    final domain = _groupDomains[groupKey];
    if (loaded == null || domain == null) return loadGroupItems(groupKey);
    try {
      final more = await _service.fetchHistory(
        domainOverride: domain,
        limit: _groupPageSize,
        offset: loaded.length,
      );
      _loadedGroups[groupKey] = [...loaded, ...more];
      notifyListeners();
    } catch (_) {}
  }

  void resetState() {
    _items = [];
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    _totalCount = 0;
    _hasLoadedOnce = false;
    _hasAutoRetriedInitialLoad = false;
    _searchQuery = '';
    _dateFrom = null;
    _dateTo = null;
    _status = defaultStatus;
    _pickingTypeCodes = [];
    _activeOnly = false;
    _inventoryOnly = false;
    _groupBy = null;
    _clearGroups();
    notifyListeners();
  }
}
