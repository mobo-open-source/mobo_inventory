
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

  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  bool _hasLoadedOnce = false;

  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _status;
  List<String> _pickingTypeCodes = [];
  bool _activeOnly = false;
  bool _inventoryOnly = false;

  String?
  _groupBy;
  final Map<String, String> _groupByOptions = {
    'product': 'Product',
    'state': 'Status',
    'location': 'Location (From → To)',
    'category': 'Category',
    'transfer': 'Transfer',
    'date:day': 'Date (Day)',
  };

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
          } catch (e) {
      _error = 'Failed to fetch history: ${OdooErrorMapper.toUserMessage(e)}';
          } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
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
    _currentPage = 1;
    notifyListeners();
  }

  void setGroupBy(String? field) {
    _groupBy = field;
    notifyListeners();
  }

  void resetState() {
    _items = [];
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    _totalCount = 0;
    _hasLoadedOnce = false;
    _searchQuery = '';
    _dateFrom = null;
    _dateTo = null;
    _status = null;
    _pickingTypeCodes = [];
    _activeOnly = false;
    _inventoryOnly = false;
    _groupBy = null;
    notifyListeners();
      }
}
