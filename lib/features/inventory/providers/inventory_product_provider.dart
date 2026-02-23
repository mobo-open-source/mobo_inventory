import 'package:flutter/material.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/services/odoo_metadata_service.dart';
import '../models/inventory_product.dart';
import '../services/inventory_product_service.dart';
import '../services/inventory_group_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/connectivity_service.dart';

/// Provider for managing the state of inventory products, including filtering and pagination.
class InventoryProductProvider with ChangeNotifier {
  final InventoryProductService _service;
  final InventoryGroupService _groupService;

  InventoryProductProvider({
    InventoryProductService? service,
    InventoryGroupService? groupService,
  }) : _service = service ?? InventoryProductService(),
       _groupService = groupService ?? InventoryGroupService();

  List<InventoryProduct> _products = [];
  bool _isLoading = false;
  bool _isOfflineCached = false;

  static const int _pageSize = 40;
  int _currentPage = 0;
  bool _hasMoreData = true;
  int _totalProducts = 0;
  String? _error;
  bool _hasLoadedOnce = false;

  String _currentSearchQuery = '';
  List<String> _selectedCategories = [];
  bool? _inStockOnly;
  String? _productType;
  bool? _isStorable = true;
  bool? _availableInPos;
  bool? _saleOk;
  bool? _purchaseOk;
  bool? _hasActivityException;
  bool? _isActive = true;
  bool? _hasNegativeStock;

  Map<String, String> _groupByOptions = {};
  String? _selectedGroupBy;
  bool _isGrouped = false;
  Map<String, int> _groupSummary = {};
  final Map<String, List<InventoryProduct>> _loadedGroups = {};

  List<String> _categories = [];

  List<InventoryProduct> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  int get totalProducts => _totalProducts;
  String? get error => _error;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get isOfflineCached => _isOfflineCached;
  List<String> get categories => _categories;
  Map<String, String> get groupByOptions => _groupByOptions;
  String? get selectedGroupBy => _selectedGroupBy;
  bool get isGrouped => _isGrouped;
  Map<String, int> get groupSummary => _groupSummary;
  Map<String, List<InventoryProduct>> get loadedGroups => _loadedGroups;
  List<String> get selectedCategories => _selectedCategories;
  bool? get inStockOnly => _inStockOnly;
  String? get productType => _productType;
  bool? get isStorable => _isStorable;
  bool? get availableInPos => _availableInPos;
  bool? get saleOk => _saleOk;
  bool? get purchaseOk => _purchaseOk;
  bool? get hasActivityException => _hasActivityException;
  bool? get isActive => _isActive;
  bool? get hasNegativeStock => _hasNegativeStock;

  int get pageSize => _pageSize;
  int get currentPage => _currentPage;
  int get currentStartIndex => (_currentPage * _pageSize) + 1;
  int get currentEndIndex => (_currentPage + 1) * _pageSize > _totalProducts
      ? _totalProducts
      : (_currentPage + 1) * _pageSize;
  int get totalPages =>
      _totalProducts > 0 ? ((_totalProducts - 1) ~/ _pageSize) + 1 : 0;
  bool get canGoToPreviousPage => _currentPage > 0;
  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalProducts;

  String getPaginationText() {
    if (_totalProducts == 0 && _products.isEmpty) return "0 items";
    if (_totalProducts == 0) return "${_products.length} items";

    final pageStart = (_currentPage * _pageSize) + 1;
    final pageEnd = currentEndIndex;
    return "$pageStart-$pageEnd/$_totalProducts";
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
    if (_isLoading) return;

    _isLoading = true;
    _products = [];
    _error = null;
    _isOfflineCached = false;
    notifyListeners();

    try {
      final hasProduct = await OdooMetadataService.hasModel('product.product');
      if (!hasProduct) {
        _isLoading = false;
        _error = OdooErrorMapper.toUserMessage("KeyError: 'product.product'");
        notifyListeners();
        return;
      }
      final offset = _currentPage * _pageSize;
      final products = await _service.fetchProducts(
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categories: _selectedCategories,
        inStockOnly: _inStockOnly,
        productType: _productType,
        isStorable: _isStorable,
        availableInPos: _availableInPos,
        saleOk: _saleOk,
        purchaseOk: _purchaseOk,
        hasActivityException: _hasActivityException,
        isActive: _isActive,
        hasNegativeStock: _hasNegativeStock,
        limit: _pageSize,
        offset: offset,
      );

      _products = products;
      _hasMoreData = products.length >= _pageSize;

      try {
        final maps = products
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'displayname': p.displayname,
                'default_code': p.defaultCode,
                'barcode': p.barcode,
                'qty_on_hand': p.qtyOnHand,
                'qty_incoming': p.qtyIncoming,
                'qty_outgoing': p.qtyOutgoing,
                'qty_available': p.qtyAvailable,
                'free_qty': p.freeQty,
                'avg_cost': p.avgCost,
                'total_value': p.totalValue,
                'uom_id': p.uomId,
                'categ_id': p.categId,
                'image_small': p.imageSmall,
              },
            )
            .toList();
      } catch (_) {}
    } catch (e) {
      if (e is NoInternetException || e is ServerUnreachableException) {
        try {
          _products = [];
          _hasMoreData = false;
          _error = OdooErrorMapper.toUserMessage(e);
        } catch (_) {
          _products = [];
          _hasMoreData = false;
          _error = OdooErrorMapper.toUserMessage(e);
        }
      } else {
        _error = OdooErrorMapper.toUserMessage(e);
      }
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  /// Fetches the first page of products with the given filters.
  Future<void> fetchProducts({
    String? searchQuery,
    List<String>? categories,
    bool? inStockOnly,
    String? productType,
    bool? isStorable,
    bool? availableInPos,
    bool? saleOk,
    bool? purchaseOk,
    bool? hasActivityException,
    bool? isActive,
    bool? hasNegativeStock,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _products = [];
      _isLoading = false;
      _currentPage = 0;
      _hasMoreData = true;
      _totalProducts = 0;
      notifyListeners();
    }

    if (_isLoading) {
      return;
    }

    _currentSearchQuery = searchQuery ?? _currentSearchQuery;
    _selectedCategories = categories ?? _selectedCategories;
    _inStockOnly = inStockOnly;
    _productType = productType;
    _isStorable = isStorable;
    _availableInPos = availableInPos;
    _saleOk = saleOk;
    _purchaseOk = purchaseOk;
    _hasActivityException = hasActivityException;
    _isActive = isActive;
    _hasNegativeStock = hasNegativeStock;

    _isLoading = true;
    _error = null;
    _isOfflineCached = false;
    _currentPage = 0;
    notifyListeners();

    try {
      final products = await _service.fetchProducts(
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categories: _selectedCategories,
        inStockOnly: _inStockOnly,
        productType: _productType,
        isStorable: _isStorable,
        availableInPos: _availableInPos,
        saleOk: _saleOk,
        purchaseOk: _purchaseOk,
        hasActivityException: _hasActivityException,
        isActive: _isActive,
        hasNegativeStock: _hasNegativeStock,
        limit: _pageSize,
        offset: 0,
      );

      final count = await _service.getProductCount(
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categories: _selectedCategories,
        inStockOnly: _inStockOnly,
        productType: _productType,
        isStorable: _isStorable,
        availableInPos: _availableInPos,
        saleOk: _saleOk,
        purchaseOk: _purchaseOk,
        hasActivityException: _hasActivityException,
        isActive: _isActive,
        hasNegativeStock: _hasNegativeStock,
      );

      _products = products;
      _totalProducts = count;
      _hasMoreData = products.length >= _pageSize;

      try {
        final maps = products
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'displayname': p.displayname,
                'default_code': p.defaultCode,
                'barcode': p.barcode,
                'qty_on_hand': p.qtyOnHand,
                'qty_incoming': p.qtyIncoming,
                'qty_outgoing': p.qtyOutgoing,
                'qty_available': p.qtyAvailable,
                'free_qty': p.freeQty,
                'avg_cost': p.avgCost,
                'total_value': p.totalValue,
                'uom_id': p.uomId,
                'categ_id': p.categId,
                'image_small': p.imageSmall,
              },
            )
            .toList();
      } catch (_) {}
    } catch (e) {
      if (e is NoInternetException || e is ServerUnreachableException) {
        try {
          _products = [];
          _totalProducts = 0;
          _hasMoreData = false;
          _error = OdooErrorMapper.toUserMessage(e);
        } catch (_) {
          _products = [];
          _totalProducts = 0;
          _hasMoreData = false;
          _error = OdooErrorMapper.toUserMessage(e);
        }
      } else {
        _error = OdooErrorMapper.toUserMessage(e);
      }
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final hasCategory = await OdooMetadataService.hasModel(
        'product.category',
      );
      if (!hasCategory) {
        _categories = [];
        notifyListeners();
        return;
      }
      final cats = await _service.fetchCategories();
      _categories = cats;
      notifyListeners();
    } catch (e) {}
  }

  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    _isGrouped = groupBy != null;
    if (groupBy == null) {
      _groupSummary.clear();
      _loadedGroups.clear();
    }
    notifyListeners();
  }

  Future<void> fetchGroupByOptions() async {
    try {
      final hasProduct = await OdooMetadataService.hasModel('product.product');
      if (!hasProduct) {
        _groupByOptions = {};
        notifyListeners();
        return;
      }

      final fieldsResult = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': ['string', 'type'],
        },
      });

      final fields = fieldsResult as Map<String, dynamic>;

      final options = <String, String>{
        'type': 'Product Type',
        'categ_id': 'Product Category',
        'pos_categ_ids': 'POS Category',
      };

      _groupByOptions = {};
      options.forEach((key, value) {
        if (fields.containsKey(key)) {
          _groupByOptions[key] = value;
        }
      });

      notifyListeners();
    } catch (e) {}
  }

  Future<void> fetchGroupSummary() async {
    if (_selectedGroupBy == null) return;

    try {
      final summary = await _groupService.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categories: _selectedCategories,
        inStockOnly: _inStockOnly,
        productType: _productType,
        isStorable: _isStorable,
        availableInPos: _availableInPos,
        saleOk: _saleOk,
        purchaseOk: _purchaseOk,
        hasActivityException: _hasActivityException,
        isActive: _isActive,
        hasNegativeStock: _hasNegativeStock,
      );

      _groupSummary = summary;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> loadGroupProducts(String groupKey) async {
    if (_selectedGroupBy == null) return;

    try {
      final products = await _groupService.fetchGroupProducts(
        groupKey: groupKey,
        groupByField: _selectedGroupBy!,
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categories: _selectedCategories,
        inStockOnly: _inStockOnly,
        productType: _productType,
        isStorable: _isStorable,
        availableInPos: _availableInPos,
        saleOk: _saleOk,
        purchaseOk: _purchaseOk,
        hasActivityException: _hasActivityException,
        isActive: _isActive,
        hasNegativeStock: _hasNegativeStock,
        limit: 50,
        offset: 0,
      );

      _loadedGroups[groupKey] = products;
      notifyListeners();
    } catch (e) {}
  }

  void clearFilters() {
    _selectedCategories = [];
    _inStockOnly = null;
    _productType = 'product';
    _isStorable = true;
    _availableInPos = null;
    _saleOk = null;
    _purchaseOk = null;
    _hasActivityException = null;
    _isActive = true;
    _hasNegativeStock = null;
    _selectedGroupBy = null;
    _isGrouped = false;
    _groupSummary.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  void resetState() {
    _products = [];
    _isLoading = false;
    _currentPage = 0;
    _hasMoreData = true;
    _totalProducts = 0;
    _error = null;
    _hasLoadedOnce = false;
    _currentSearchQuery = '';
    _selectedCategories = [];
    _inStockOnly = null;
    _productType = 'product';
    _isStorable = true;
    _availableInPos = null;
    _saleOk = null;
    _purchaseOk = null;
    _hasActivityException = null;
    _isActive = true;
    _hasNegativeStock = null;
    _groupByOptions = {};
    _selectedGroupBy = null;
    _isGrouped = false;
    _groupSummary = {};
    _loadedGroups.clear();
    _categories = [];
    notifyListeners();
  }
}
