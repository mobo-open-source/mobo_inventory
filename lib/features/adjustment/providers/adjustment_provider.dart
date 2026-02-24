import 'package:flutter/foundation.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/exceptions/inventory_exceptions.dart';
import '../../../core/services/odoo_metadata_service.dart';
import '../models/inventory_adjustment_model.dart';
import '../services/adjustment_service.dart';

/// State manager for inventory adjustment operations, handling data fetching, filtering, and quantity updates.
class AdjustmentProvider extends ChangeNotifier {
  final AdjustmentService _service = AdjustmentService();

  List<InventoryAdjustment> adjustments = [];
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = false;
  String? _error;

  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  String _searchQuery = '';
  int? _selectedLocationId;
  String? _selectedGroupBy;

  bool _filterInternalLocations = true;
  bool _filterTransitLocations = true;
  bool _filterOnHand = false;
  bool _filterToCount = false;
  bool _filterToApply = false;
  bool _filterInStock = false;
  bool _filterConflicts = false;
  bool _filterNegativeStock = false;
  DateTime? _incomingDateStart;
  DateTime? _incomingDateEnd;

  bool _reservedOnly = false;
  bool _mineOnly = false;
  bool _quantityPositive = false;
  bool _onHandFlag = false;
  bool _incomingDateToToday = false;
  bool _countedSet = false;

  List<Map<String, dynamic>> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  int get pageSize => _pageSize;
  String get searchQuery => _searchQuery;
  int? get selectedLocationId => _selectedLocationId;
  String? get selectedGroupBy => _selectedGroupBy;
  bool get isGrouped =>
      _selectedGroupBy != null && _selectedGroupBy!.isNotEmpty;

  bool get filterInternalLocations => _filterInternalLocations;
  bool get filterTransitLocations => _filterTransitLocations;
  bool get filterOnHand => _filterOnHand;
  bool get filterToCount => _filterToCount;
  bool get filterToApply => _filterToApply;
  bool get filterInStock => _filterInStock;
  bool get filterConflicts => _filterConflicts;
  bool get filterNegativeStock => _filterNegativeStock;
  DateTime? get incomingDateStart => _incomingDateStart;
  DateTime? get incomingDateEnd => _incomingDateEnd;
  bool get reservedOnly => _reservedOnly;
  bool get mineOnly => _mineOnly;
  bool get quantityPositive => _quantityPositive;
  bool get onHandFlag => _onHandFlag;
  bool get incomingDateToToday => _incomingDateToToday;
  bool get countedSet => _countedSet;

  bool get canGoToPreviousPage => _currentPage > 1;
  bool get canGoToNextPage => (_currentPage * _pageSize) < _totalCount;

  String getPaginationText() {
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize).clamp(0, _totalCount);
    return "$start-$end/$_totalCount";
  }

  Future<void> fetchAdjustments({
    String? searchQuery,
    int? productId,
    int? locationId,
    bool? internalLocations,
    bool? transitLocations,
    bool? onHand,
    bool? onHandFlag,
    bool? quantityPositive,
    bool? toCount,
    bool? countedSet,
    bool? toApply,
    bool? inStock,
    bool? conflicts,
    bool? negativeStock,
    bool? reservedOnly,
    bool? mineOnly,
    DateTime? incomingDateStart,
    DateTime? incomingDateEnd,
    bool? incomingDateToToday,
    bool updateFilters = false,
  }) async {
    try {
      if (_isLoading && updateFilters != true) return;

      _isLoading = true;
      _error = null;
      adjustments.clear();
      notifyListeners();

      if (updateFilters) {
        _searchQuery = searchQuery ?? '';
        _selectedLocationId = locationId;
        if (internalLocations != null)
          _filterInternalLocations = internalLocations;
        if (transitLocations != null)
          _filterTransitLocations = transitLocations;
        if (onHand != null) _filterOnHand = onHand;
        if (onHandFlag != null) _onHandFlag = onHandFlag;
        if (quantityPositive != null) _quantityPositive = quantityPositive;
        if (toCount != null) _filterToCount = toCount;
        if (countedSet != null) _countedSet = countedSet;
        if (toApply != null) _filterToApply = toApply;
        if (inStock != null) _filterInStock = inStock;
        if (conflicts != null) _filterConflicts = conflicts;
        if (negativeStock != null) _filterNegativeStock = negativeStock;
        if (reservedOnly != null) _reservedOnly = reservedOnly;
        if (mineOnly != null) _mineOnly = mineOnly;
        _incomingDateStart = incomingDateStart;
        _incomingDateEnd = incomingDateEnd;
        if (incomingDateToToday != null)
          _incomingDateToToday = incomingDateToToday;
        _currentPage = 1;
      }

      notifyListeners();

      final hasQuant = await OdooMetadataService.hasModel('stock.quant');
      if (!hasQuant) {
        _isLoading = false;
        _error = OdooErrorMapper.toUserMessage("KeyError: 'stock.quant'");
        notifyListeners();
        return;
      }

      final offset = (_currentPage - 1) * _pageSize;

      final results = await Future.wait([
        _service.fetchAdjustments(
          offset: offset,
          limit: _pageSize,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          productId: productId,
          locationId: _selectedLocationId,
          internalLocations: _filterInternalLocations,
          transitLocations: _filterTransitLocations,
          onHand: _filterOnHand,
          onHandFlag: _onHandFlag,
          quantityPositive: _quantityPositive,
          toCount: _filterToCount,
          countedSet: _countedSet,
          toApply: _filterToApply,
          inStock: _filterInStock,
          conflicts: _filterConflicts,
          negativeStock: _filterNegativeStock,
          reservedOnly: _reservedOnly,
          mineOnly: _mineOnly,
          incomingDateStart: _incomingDateStart,
          incomingDateEnd: _incomingDateEnd,
          incomingDateToToday: _incomingDateToToday,
        ),
        _service.getAdjustmentCount(
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          productId: productId,
          locationId: _selectedLocationId,
          internalLocations: _filterInternalLocations,
          transitLocations: _filterTransitLocations,
          onHand: _filterOnHand,
          onHandFlag: _onHandFlag,
          quantityPositive: _quantityPositive,
          toCount: _filterToCount,
          countedSet: _countedSet,
          toApply: _filterToApply,
          inStock: _filterInStock,
          conflicts: _filterConflicts,
          negativeStock: _filterNegativeStock,
          reservedOnly: _reservedOnly,
          mineOnly: _mineOnly,
          incomingDateStart: _incomingDateStart,
          incomingDateEnd: _incomingDateEnd,
          incomingDateToToday: _incomingDateToToday,
        ),
      ]);

      adjustments = results[0] as List<InventoryAdjustment>;
      _totalCount = results[1] as int;

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error =
          'Failed to fetch adjustments: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLocations() async {
    try {
      _locations = await _service.fetchLocations();
      notifyListeners();
    } catch (e) {}
  }

  Future<bool> updateCountedQuantity({
    required int quantId,
    required double countedQuantity,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.updateInventoryQuantity(
        quantId: quantId,
        countedQuantity: countedQuantity,
      );

      if (success) {
        final index = adjustments.indexWhere((adj) => adj.id == quantId);
        if (index != -1) {
          adjustments[index] = adjustments[index].copyWith(
            countedQuantity: countedQuantity,
            difference: countedQuantity - adjustments[index].onHandQuantity,
          );

          notifyListeners();
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to update quantity: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> applyAdjustment(int quantId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.applyAdjustment(quantId);

      if (success) {
        final index = adjustments.indexWhere((adj) => adj.id == quantId);
        if (index != -1) {
          adjustments.removeAt(index);
          _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;

          notifyListeners();
        }

        fetchAdjustments();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      if (e is ValidationException) {
        _error = e.userMessage;
      } else if (e is OdooApiException) {
        _error = e.message;
      } else {
        _error =
            'Failed to apply adjustment: ${OdooErrorMapper.toUserMessage(e)}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> goToNextPage() async {
    if (canGoToNextPage && !_isLoading) {
      _currentPage++;
      await fetchAdjustments();
    }
  }

  Future<void> goToPreviousPage() async {
    if (canGoToPreviousPage && !_isLoading) {
      _currentPage--;
      await fetchAdjustments();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedLocationId = null;
    _selectedGroupBy = null;
    _filterInternalLocations = true;
    _filterTransitLocations = true;
    _filterOnHand = false;
    _filterToCount = false;
    _filterToApply = false;
    _filterInStock = false;
    _filterConflicts = false;
    _filterNegativeStock = false;
    _incomingDateStart = null;
    _incomingDateEnd = null;
    _reservedOnly = false;
    _mineOnly = false;
    _quantityPositive = false;
    _onHandFlag = false;
    _incomingDateToToday = false;
    _countedSet = false;
    _currentPage = 1;
    notifyListeners();
  }

  Future<void> refresh() async {
    _currentPage = 1;
    await fetchAdjustments();
  }

  void setGroupBy(String? field) {
    _selectedGroupBy = field;
    notifyListeners();
  }

  void resetState() {
    adjustments = [];
    _locations = [];
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    _totalCount = 0;
    _searchQuery = '';
    _selectedLocationId = null;
    _selectedGroupBy = null;
    _filterInternalLocations = true;
    _filterTransitLocations = true;
    _filterOnHand = false;
    _filterToCount = false;
    _filterToApply = false;
    _filterInStock = false;
    _filterConflicts = false;
    _filterNegativeStock = false;
    _incomingDateStart = null;
    _incomingDateEnd = null;
    _reservedOnly = false;
    _mineOnly = false;
    _quantityPositive = false;
    _onHandFlag = false;
    _incomingDateToToday = false;
    _countedSet = false;
    notifyListeners();
  }
}
