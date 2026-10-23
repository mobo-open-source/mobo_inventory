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

  /// Counts the list fetches (a search, a page) and the group-summary fetches
  /// started. A fetch that is no longer the latest when its answer arrives —
  /// a slow search overtaken by the next one — is dropped, so it cannot
  /// overwrite what the newer one loaded.
  int _listSeq = 0;
  int _groupSeq = 0;

  String _currentSearchQuery = '';
  List<String> _selectedCategories = [];
  bool? _inStockOnly;
  String? _productType;
  bool? _isStorable;
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
  // Group label -> the Odoo domain that selects that group's products.
  final Map<String, List<dynamic>> _groupDomains = {};

  /// Category id -> full path; [_categories] are its labels.
  Map<int, String> _categoryMap = {};
  List<String> _categories = [];

  /// `product.product.type` as the server defines it (value -> label): Odoo
  /// 18 replaced Storable / Consumable with Goods (`consu`) and added Combo.
  Map<String, String> _typeOptions = {};

  /// Odoo 18+ marks a storable product with `is_storable`.
  bool _hasStorableField = false;

  /// `available_in_pos` only exists with the Point of Sale app installed.
  bool _hasPosField = false;

  List<InventoryProduct> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  int get totalProducts => _totalProducts;
  String? get error => _error;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get isOfflineCached => _isOfflineCached;
  List<String> get categories => _categories;
  Map<String, String> get typeOptions => _typeOptions;
  bool get hasStorableField => _hasStorableField;
  bool get hasPosField => _hasPosField;

  /// The search the list (and the groups) are filtered by.
  String get searchQuery => _currentSearchQuery;

  List<int> get _selectedCategoryIds => [
    for (final entry in _categoryMap.entries)
      if (_selectedCategories.contains(entry.value)) entry.key,
  ];

  List<dynamic> get _domain => InventoryProductService.buildDomain(
    searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
    categoryIds: _selectedCategoryIds,
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

    final seq = ++_listSeq;
    _isLoading = true;
    _products = [];
    _error = null;
    _isOfflineCached = false;
    notifyListeners();

    try {
      final hasProduct = await OdooMetadataService.hasModel('product.product');
      if (seq != _listSeq) return;
      if (!hasProduct) {
        _isLoading = false;
        _error = OdooErrorMapper.toUserMessage("KeyError: 'product.product'");
        notifyListeners();
        return;
      }
      final offset = _currentPage * _pageSize;
      final products = await _service.fetchProducts(
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categoryIds: _selectedCategoryIds,
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

      if (seq != _listSeq) return;
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
      if (seq != _listSeq) return;
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
      // Only the latest fetch ends the loading: an older one finishing must
      // not clear it while the newer is still on its way.
      if (seq == _listSeq) {
        _isLoading = false;
        _hasLoadedOnce = true;
        notifyListeners();
      }
    }
  }

  /// Replaces every list filter (null clears it) and reloads the first page.
  Future<void> applyFilters({
    List<String> categories = const [],
    bool? inStockOnly,
    String? productType,
    bool? isStorable,
    bool? availableInPos,
    bool? saleOk,
    bool? purchaseOk,
    bool? isActive,
  }) {
    _selectedCategories = categories;
    _inStockOnly = inStockOnly;
    _productType = productType;
    _isStorable = isStorable;
    _availableInPos = availableInPos;
    _saleOk = saleOk;
    _purchaseOk = purchaseOk;
    _isActive = isActive;
    return fetchProducts(forceRefresh: true);
  }

  /// Fetches the first page of products with the current filters.
  ///
  /// Filters are only changed through [applyFilters] / [clearFilters], so a
  /// search or a refresh keeps the ones applied.
  Future<void> fetchProducts({
    String? searchQuery,
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

    final seq = ++_listSeq;
    _isLoading = true;
    _error = null;
    _isOfflineCached = false;
    _currentPage = 0;
    notifyListeners();

    try {
      final products = await _service.fetchProducts(
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
        categoryIds: _selectedCategoryIds,
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
        categoryIds: _selectedCategoryIds,
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

      if (seq != _listSeq) return;
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
      if (seq != _listSeq) return;
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
      if (seq == _listSeq) {
        _isLoading = false;
        _hasLoadedOnce = true;
        notifyListeners();
      }
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
      _categoryMap = await _service.fetchCategories();
      _categories = _categoryMap.values.toList();
      notifyListeners();
    } catch (e) {}
  }

  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    _isGrouped = groupBy != null;
    // A summary still on its way belongs to the old grouping.
    _groupSeq++;
    if (groupBy == null) {
      _groupSummary.clear();
      _groupDomains.clear();
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
          'attributes': ['string', 'type', 'selection'],
        },
      });

      final fields = fieldsResult as Map<String, dynamic>;

      final typeField = fields['type'];
      final selection = typeField is Map ? typeField['selection'] : null;
      _typeOptions = {
        if (selection is List)
          for (final option in selection)
            if (option is List && option.length >= 2)
              option[0].toString(): option[1].toString(),
      };
      _hasStorableField = fields.containsKey('is_storable');
      _hasPosField = fields.containsKey('available_in_pos');

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

    final seq = ++_groupSeq;
    try {
      final domains = <String, List<dynamic>>{};
      final summary = await _groupService.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        domain: _domain,
        domainsOut: domains,
        typeLabels: _typeOptions,
      );

      // Overtaken by a newer search or filter, or the grouping was removed.
      if (seq != _groupSeq) return;

      // Groups already open are reloaded under the new filters rather than
      // left showing the products of the old ones.
      final reopen = _loadedGroups.keys.where(summary.containsKey).toList();
      _groupSummary = summary;
      _groupDomains
        ..clear()
        ..addAll(domains);
      _loadedGroups.clear();
      notifyListeners();
      for (final groupKey in reopen) {
        await loadGroupProducts(groupKey);
      }
    } catch (e) {}
  }

  Future<void> loadGroupProducts(String groupKey) async {
    if (_selectedGroupBy == null) return;

    try {
      if (!_groupDomains.containsKey(groupKey)) await fetchGroupSummary();
      final domain = _groupDomains[groupKey];
      if (domain == null) return;

      final products = await _groupService.fetchGroupProducts(
        domain: domain,
        limit: _groupPageSize,
        offset: 0,
      );

      // A newer summary (say, after the search changed) replaced the group's
      // domain while this loaded: these are the old search's products.
      if (!identical(_groupDomains[groupKey], domain)) return;
      _loadedGroups[groupKey] = products;
      notifyListeners();
    } catch (e) {}
  }

  /// Products a group (a kanban column, an expanded group) loads at a time.
  static const int _groupPageSize = 50;

  /// Appends the next page of [groupKey]'s products to those it shows —
  /// the "Load more" of a group holding more than [_groupPageSize].
  Future<void> loadMoreGroupProducts(String groupKey) async {
    final loaded = _loadedGroups[groupKey];
    final domain = _groupDomains[groupKey];
    if (loaded == null || domain == null) return loadGroupProducts(groupKey);

    try {
      final more = await _groupService.fetchGroupProducts(
        domain: domain,
        limit: _groupPageSize,
        offset: loaded.length,
      );
      if (!identical(_groupDomains[groupKey], domain)) return;
      _loadedGroups[groupKey] = [...loaded, ...more];
      notifyListeners();
    } catch (_) {
      // Like a group's first load: the group keeps what it shows.
    }
  }

  void clearFilters() {
    _selectedCategories = [];
    _inStockOnly = null;
    _productType = null;
    _isStorable = null;
    _availableInPos = null;
    _saleOk = null;
    _purchaseOk = null;
    _hasActivityException = null;
    _isActive = true;
    _hasNegativeStock = null;
    _selectedGroupBy = null;
    _isGrouped = false;
    _groupSeq++;
    _groupSummary.clear();
    _groupDomains.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  void resetState() {
    // Answers still on their way are for the state being discarded.
    _listSeq++;
    _groupSeq++;
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
    _productType = null;
    _isStorable = null;
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
    _groupDomains.clear();
    _loadedGroups.clear();
    _categoryMap = {};
    _categories = [];
    _typeOptions = {};
    _hasStorableField = false;
    _hasPosField = false;
    notifyListeners();
  }
}
