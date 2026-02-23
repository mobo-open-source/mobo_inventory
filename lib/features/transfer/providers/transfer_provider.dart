import 'package:flutter/material.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/odoo_metadata_service.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';

/// State manager for internal transfer operations, handling fetching, filtering, and creation.
class TransferProvider extends ChangeNotifier {
  final TransferService _service = TransferService();

  bool _isLoading = false;
  String? _error;
  List<InternalTransfer> _transfers = [];
  int _totalCount = 0;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasLoadedOnce = false;

  String _searchQuery = '';
  List<String> _selectedStates = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;

  Map<String, int> _groupSummary = {};
  final Map<String, List<InternalTransfer>> _loadedGroups = {};

  List<Map<String, dynamic>> _pickingTypes = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _products = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<InternalTransfer> get transfers => _transfers;
  int get totalCount => _totalCount;
  String get searchQuery => _searchQuery;
  List<String> get selectedStates => _selectedStates;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedGroupBy => _selectedGroupBy;
  bool get isGrouped => _selectedGroupBy != null;
  Map<String, int> get groupSummary => _groupSummary;
  Map<String, List<InternalTransfer>> get loadedGroups => _loadedGroups;

  List<Map<String, dynamic>> get pickingTypes => _pickingTypes;
  List<Map<String, dynamic>> get locations => _locations;
  List<Map<String, dynamic>> get products => _products;

  int get pageSize => _pageSize;
  int get currentPage => _currentPage;
  int get currentStartIndex => (_currentPage * _pageSize) + 1;
  int get currentEndIndex => (_currentPage + 1) * _pageSize > _totalCount
      ? _totalCount
      : (_currentPage + 1) * _pageSize;
  int get totalPages =>
      _totalCount > 0 ? ((_totalCount - 1) ~/ _pageSize) + 1 : 0;
  bool get canGoToPreviousPage => _currentPage > 0;
  bool get canGoToNextPage => (_currentPage + 1) * _pageSize < _totalCount;
  bool get hasLoadedOnce => _hasLoadedOnce;

  String getPaginationText() {
    if (_totalCount == 0 && _transfers.isEmpty) return "0 items";
    if (_totalCount == 0) return "${_transfers.length} items";

    final pageStart = (_currentPage * _pageSize) + 1;
    final pageEnd = currentEndIndex;
    return "$pageStart-$pageEnd/$_totalCount";
  }

  Future<void> fetchPickingTypes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final allowedIds =
          await OdooSessionManager.getSelectedAllowedCompanyIds();
      final List<dynamic> domain = [
        ['code', '=', 'internal'],
      ];
      if (allowedIds.isNotEmpty) {
        domain.add('|');
        domain.add(['company_id', '=', false]);
        domain.add(['company_id', 'in', allowedIds]);
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking.type',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'display_name',
            'company_id',
            'default_location_src_id',
            'default_location_dest_id',
            'code',
          ],
        },
      });

      if (res is List) {
        _pickingTypes = res.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error =
          'Failed to fetch picking types: ${OdooErrorMapper.toUserMessage(e)}';
    } finally {
      await fetchTransfers(forceRefresh: true, updateFilters: false);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLocations() async {
    try {
      final allowedIds =
          await OdooSessionManager.getSelectedAllowedCompanyIds();
      final List<dynamic> domain = [
        ['usage', '=', 'internal'],
      ];
      if (allowedIds.isNotEmpty) {
        domain.add('|');
        domain.add(['company_id', '=', false]);
        domain.add(['company_id', 'in', allowedIds]);
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'complete_name', 'company_id'],
          'limit': 100,
        },
      });

      if (res is List) {
        _locations = res.cast<Map<String, dynamic>>();
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch locations: ${OdooErrorMapper.toUserMessage(e)}';
      notifyListeners();
    }
  }

  Future<void> fetchProducts({String? search}) async {
    try {
      final domain = [];
      if (search != null && search.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', search]);
        domain.add(['default_code', 'ilike', search]);
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'display_name',
            'default_code',
            'barcode',
            'uom_id',
            'qty_available',
            'virtual_available',
            'type',
            'list_price',
            'standard_price',
            'categ_id',
            'image_128',
          ],
          'limit': 50,
          'order': 'name asc',
        },
      });

      _products = res.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch products: ${OdooErrorMapper.toUserMessage(e)}';
      notifyListeners();
    }
  }

  Future<int?> createInternalTransfer({
    required int pickingTypeId,
    required int locationId,
    required int locationDestId,
    required List<Map<String, dynamic>> moveLines,
    String? scheduledDate,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final formattedDate = scheduledDate != null
          ? _formatDateTimeForOdoo(scheduledDate)
          : null;

      int? _extractCompanyId(dynamic cmp) {
        if (cmp is int) return cmp;
        if (cmp is List && cmp.isNotEmpty) return cmp[0] as int?;
        return null;
      }

      int? companyIdForPicking;
      try {
        final pt = _pickingTypes.firstWhere(
          (e) => (e['id'] as int) == pickingTypeId,
          orElse: () => <String, dynamic>{},
        );
        companyIdForPicking = _extractCompanyId(pt['company_id']);
      } catch (_) {}

      companyIdForPicking ??= await OdooSessionManager.getSelectedCompanyId();

      int? _locCompany(int id) {
        try {
          final loc = _locations.firstWhere(
            (e) => (e['id'] as int) == id,
            orElse: () => <String, dynamic>{},
          );
          return _extractCompanyId(loc['company_id']);
        } catch (_) {
          return null;
        }
      }

      bool _companyMatches(int? a, int? b) => a == null || b == null || a == b;

      final srcCmp = _locCompany(locationId);
      final dstCmp = _locCompany(locationDestId);
      if (!_companyMatches(companyIdForPicking, srcCmp) ||
          !_companyMatches(companyIdForPicking, dstCmp)) {
        _isLoading = false;
        _error =
            'Selected Operation Type and Locations must belong to the same company.';
        notifyListeners();
        throw Exception(_error);
      }

      final allowed = companyIdForPicking != null
          ? [companyIdForPicking]
          : <int>[];

      final pickingResult = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'create',
          'args': [
            {
              'picking_type_id': pickingTypeId,
              'location_id': locationId,
              'location_dest_id': locationDestId,
              if (formattedDate != null) 'scheduled_date': formattedDate,
            },
          ],
          'kwargs': {},
        },
        companyId: companyIdForPicking,
        allowedCompanyIds: allowed,
      );

      if (pickingResult == null) {
        throw Exception('Failed to create transfer: No picking ID returned');
      }

      final pickingId = pickingResult is int
          ? pickingResult
          : int.parse(pickingResult.toString());

      final session = await OdooSessionManager.getCurrentSession();
      final versionStr = session?.odooSession.serverVersion ?? '16';
      final majorVersion = int.tryParse(versionStr.split('.').first) ?? 16;
      final isOdoo19OrNewer = majorVersion >= 19;

      for (final line in moveLines) {
        final Map<String, dynamic> moveVals = {
          'picking_id': pickingId,
          'product_id': line['product_id'],
          'product_uom_qty': line['quantity'],
          'product_uom': line['product_uom'],
          'location_id': locationId,
          'location_dest_id': locationDestId,
          'price_unit': (line['unit_price'] as num?)?.toDouble() ?? 0.0,
        };

        if (!isOdoo19OrNewer) {
          moveVals['name'] = line['product_name'] ?? 'Internal Transfer';
        }

        final moveResult = await OdooSessionManager.callKwWithCompany(
          {
            'model': 'stock.move',
            'method': 'create',
            'args': [moveVals],
            'kwargs': {},
          },
          companyId: companyIdForPicking,
          allowedCompanyIds: allowed,
        );
      }

      _isLoading = false;
      notifyListeners();
      return pickingId;
    } catch (e) {
      _error = 'Failed to create transfer: ${OdooErrorMapper.toUserMessage(e)}';

      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmTransfer(int pickingId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      int? pickingCompanyId;
      try {
        final readRes = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'stock.picking',
          'method': 'read',
          'args': [
            [pickingId],
            ['company_id'],
          ],
          'kwargs': {},
        });
        if (readRes is List && readRes.isNotEmpty) {
          final item = Map<String, dynamic>.from(readRes.first);
          final cmp = item['company_id'];
          if (cmp is int) {
            pickingCompanyId = cmp;
          } else if (cmp is List && cmp.isNotEmpty) {
            final first = cmp.first;
            if (first is int) pickingCompanyId = first;
          }
        }
      } catch (_) {}
      final singleAllowed = pickingCompanyId != null
          ? [pickingCompanyId]
          : <int>[];

      final confirmResult = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'action_confirm',
          'args': [
            [pickingId],
          ],
          'kwargs': {},
        },
        companyId: pickingCompanyId,
        allowedCompanyIds: singleAllowed,
      );

      final session = await OdooSessionManager.getCurrentSession();
      final versionStr = session?.odooSession.serverVersion ?? '16';
      final majorVersion = int.tryParse(versionStr.split('.').first) ?? 16;
      final isOdoo19OrNewer = majorVersion >= 19;
      final moveIdsField = isOdoo19OrNewer
          ? 'move_ids'
          : 'move_ids_without_package';

      final movesResult = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'read',
          'args': [
            [pickingId],
            [moveIdsField],
          ],
          'kwargs': {},
        },
        companyId: pickingCompanyId,
        allowedCompanyIds: singleAllowed,
      );

      if (movesResult is List && movesResult.isNotEmpty) {
        final pickingData = movesResult.first as Map<String, dynamic>;
        final moveIds = pickingData[moveIdsField];

        if (moveIds is List && moveIds.isNotEmpty) {
          final moveLinesResult = await OdooSessionManager.callKwWithCompany(
            {
              'model': 'stock.move',
              'method': 'read',
              'args': [
                moveIds,
                ['id', 'product_uom_qty'],
              ],
              'kwargs': {},
            },
            companyId: pickingCompanyId,
            allowedCompanyIds: singleAllowed,
          );

          if (moveLinesResult is List) {
            for (final move in moveLinesResult) {
              if (move is Map<String, dynamic>) {
                await OdooSessionManager.callKwWithCompany(
                  {
                    'model': 'stock.move',
                    'method': 'write',
                    'args': [
                      [move['id']],
                      {'quantity_done': move['product_uom_qty']},
                    ],
                    'kwargs': {},
                  },
                  companyId: pickingCompanyId,
                  allowedCompanyIds: singleAllowed,
                );
              }
            }
          }

          await OdooSessionManager.callKwWithCompany(
            {
              'model': 'stock.picking',
              'method': 'button_validate',
              'args': [
                [pickingId],
              ],
              'kwargs': {},
            },
            companyId: pickingCompanyId,
            allowedCompanyIds: singleAllowed,
          );
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error =
          'Failed to confirm transfer: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchTransfers({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    bool updateFilters = true,
  }) async {
    if (forceRefresh) {
      _transfers = [];
      _isLoading = false;
      _totalCount = 0;
      _currentPage = 0;
      notifyListeners();
    }

    if (_isLoading) return;

    if (updateFilters) {
      _searchQuery = searchQuery ?? '';

      if (states != null) {
        _selectedStates = states;
      }

      _startDate = startDate;
      _endDate = endDate;
    }

    _isLoading = true;
    _error = null;
    _currentPage = 0;
    notifyListeners();

    try {
      final hasInternal = await _service.hasInternalOperationType();
      if (!hasInternal) {
        _isLoading = false;
        _error = 'Please enable Storage Locations in Inventory settings.';
        notifyListeners();
        return;
      }

      final transfers = await _service.fetchTransfers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _selectedStates.isEmpty ? null : _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: 0,
      );

      final count = await _service.getTransferCount(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _selectedStates.isEmpty ? null : _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
      );

      _transfers = transfers;
      _totalCount = count;
      _currentPage = 0;
    } catch (e) {
      _error = 'Failed to fetch transfers: ${OdooErrorMapper.toUserMessage(e)}';
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
    _transfers = [];
    _error = null;
    notifyListeners();

    try {
      final transfers = await _service.fetchTransfers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _selectedStates.isEmpty ? null : _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      _transfers = transfers;
    } catch (e) {
      _error = 'Failed to fetch transfers: $e';
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> loadMoreTransfers() async {
    if (_isLoading || _transfers.length >= _totalCount) return;

    _isLoading = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final moreTransfers = await _service.fetchTransfers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _selectedStates.isEmpty ? null : _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      _transfers.addAll(moreTransfers);
      _currentPage = nextPage;
    } catch (e) {
      _error =
          'Failed to load more transfers: ${OdooErrorMapper.toUserMessage(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchGroupSummary() async {
    if (_selectedGroupBy == null) return;

    try {
      final summary = await _service.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: _selectedStates.isEmpty ? null : _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
      );

      _groupSummary = summary;
      _loadedGroups.clear();
      notifyListeners();
    } catch (e) {
      _error =
          'Failed to fetch group summary: ${OdooErrorMapper.toUserMessage(e)}';
      notifyListeners();
    }
  }

  Future<void> loadGroupTransfers(String groupKey) async {
    if (_loadedGroups.containsKey(groupKey)) return;

    try {
      List<String>? groupStates;
      if (_selectedGroupBy == 'state') {
        groupStates = [groupKey];
      }

      final transfers = await _service.fetchTransfers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        states: groupStates ?? _selectedStates,
        startDate: _startDate,
        endDate: _endDate,
        limit: 100,
      );

      _loadedGroups[groupKey] = transfers;
      notifyListeners();
    } catch (e) {}
  }

  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    if (groupBy == null) {
      _groupSummary.clear();
      _loadedGroups.clear();
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStates.clear();
    _startDate = null;
    _endDate = null;
    _selectedGroupBy = null;
    _groupSummary.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  Future<bool> updateInternalTransfer({
    required int transferId,
    int? locationId,
    int? locationDestId,
    String? scheduledDate,
    List<Map<String, dynamic>>? moveLines,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.updateInternalTransfer(
        transferId: transferId,
        locationId: locationId,
        locationDestId: locationDestId,
        scheduledDate: scheduledDate,
        moveLines: moveLines,
      );

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to update transfer: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _formatDateTimeForOdoo(String dateTimeStr) {
    try {
      DateTime dt = DateTime.parse(dateTimeStr);

      String formatted =
          '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';

      return formatted;
    } catch (e) {
      return dateTimeStr.replaceAll('T', ' ').replaceAll(RegExp(r'\.\d+'), '');
    }
  }

  Future<bool> cancelInternalTransfer(int transferId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.cancelInternalTransfer(transferId);
      if (success) {
        await fetchTransfers(forceRefresh: true, updateFilters: false);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to cancel transfer: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<InternalTransfer?> fetchTransferDetails(int transferId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final transfer = await _service.fetchTransferDetails(transferId);

      _isLoading = false;
      notifyListeners();
      return transfer;
    } catch (e) {
      _error =
          'Failed to fetch transfer details: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> markAsTodo(int transferId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.markAsTodo(transferId);
      if (success) {
        await fetchTransfers(forceRefresh: true, updateFilters: false);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error =
          'Failed to mark transfer as todo: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> validateTransfer(int transferId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _service.validateTransfer(transferId);
      if (success) {
        await fetchTransfers(forceRefresh: true, updateFilters: false);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error =
          'Failed to validate transfer: ${OdooErrorMapper.toUserMessage(e)}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void resetState() {
    _isLoading = false;
    _error = null;
    _transfers = [];
    _totalCount = 0;
    _currentPage = 0;
    _hasLoadedOnce = false;
    _searchQuery = '';
    _selectedStates = [];
    _startDate = null;
    _endDate = null;
    _selectedGroupBy = null;
    _groupSummary = {};
    _loadedGroups.clear();
    _pickingTypes = [];
    _locations = [];
    _products = [];
    notifyListeners();
  }
}
