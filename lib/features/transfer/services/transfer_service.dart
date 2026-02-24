import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/transfer_model.dart';

/// Service for interacting with Odoo's `stock.picking` and `stock.move` models.
class TransferService {
  Future<bool> hasInternalOperationType() async {
    try {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking.type',
        'method': 'search_count',
        'args': [
          [
            ['code', '=', 'internal'],
          ],
        ],
        'kwargs': {},
      });
      if (count is int) return count > 0;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Fetches a list of internal transfers from Odoo based on search and filter criteria.
  Future<List<InternalTransfer>> fetchTransfers({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      List<dynamic> domain = [
        ['picking_type_code', '=', 'internal'],
      ];

      if (states != null && states.isNotEmpty) {
        if (states.length == 1) {
          domain.add(['state', '=', states.first]);
        } else {
          for (int i = 0; i < states.length - 1; i++) {
            domain.add('|');
          }
          for (final state in states) {
            domain.add(['state', '=', state]);
          }
        }
      }

      if (startDate != null) {
        domain.add(['scheduled_date', '>=', startDate.toIso8601String()]);
      }
      if (endDate != null) {
        domain.add(['scheduled_date', '<=', endDate.toIso8601String()]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['origin', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'picking_type_id',
            'location_id',
            'location_dest_id',
            'scheduled_date',
            'date_done',
            'state',
            'origin',
            'user_id',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'scheduled_date desc, id desc',
        },
      });

      if (result is List) {
        return result.map((json) => InternalTransfer.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getTransferCount({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      List<dynamic> domain = [
        ['picking_type_code', '=', 'internal'],
      ];

      if (states != null && states.isNotEmpty) {
        if (states.length == 1) {
          domain.add(['state', '=', states.first]);
        } else {
          for (int i = 0; i < states.length - 1; i++) {
            domain.add('|');
          }
          for (final state in states) {
            domain.add(['state', '=', state]);
          }
        }
      }

      if (startDate != null) {
        domain.add(['scheduled_date', '>=', startDate.toIso8601String()]);
      }
      if (endDate != null) {
        domain.add(['scheduled_date', '<=', endDate.toIso8601String()]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['origin', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      final count = result as int? ?? 0;
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<InternalTransfer?> fetchTransferDetails(int transferId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final versionStr = session?.odooSession.serverVersion ?? '16';
      final majorVersion = int.tryParse(versionStr.split('.').first) ?? 16;
      final isOdoo19OrNewer = majorVersion >= 19;
      final moveIdsField = isOdoo19OrNewer
          ? 'move_ids'
          : 'move_ids_without_package';

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'read',
        'args': [
          [transferId],
          [
            'id',
            'name',
            'picking_type_id',
            'location_id',
            'location_dest_id',
            'scheduled_date',
            'date_done',
            'state',
            'origin',
            'user_id',
            moveIdsField,
          ],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final transferData = result.first as Map<String, dynamic>;

        final moveIds = transferData[moveIdsField];
        List<TransferLine> moveLines = [];

        if (moveIds is List && moveIds.isNotEmpty) {
          final movesResult = await OdooSessionManager.callKwWithCompany({
            'model': 'stock.move',
            'method': 'read',
            'args': [
              moveIds,
              [
                'id',
                'product_id',
                'product_uom_qty',
                'product_uom',
                'price_unit',
              ],
            ],
            'kwargs': {},
          });

          if (movesResult is List) {
            final List<Map<String, dynamic>> moves = movesResult
                .map((m) => Map<String, dynamic>.from(m))
                .toList();

            for (var move in moves) {
              final price = (move['price_unit'] as num?)?.toDouble() ?? 0.0;
              if (price == 0) {
                try {
                  final productId = _extractId(move['product_id']);
                  if (productId != null) {
                    final productData =
                        await OdooSessionManager.callKwWithCompany({
                          'model': 'product.product',
                          'method': 'read',
                          'args': [
                            [productId],
                            ['list_price'],
                          ],
                          'kwargs': {},
                        });
                    if (productData is List && productData.isNotEmpty) {
                      move['price_unit'] =
                          (productData.first['list_price'] as num?)
                              ?.toDouble() ??
                          0.0;
                    }
                  }
                } catch (e) {}
              }
            }

            moveLines = moves
                .map((json) => TransferLine.fromJson(json))
                .toList();
          }
        }

        return InternalTransfer.fromJson(
          transferData,
        ).copyWith(moveLines: moveLines);
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> fetchGroupSummary({
    required String groupByField,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      List<dynamic> domain = [
        ['picking_type_code', '=', 'internal'],
      ];

      if (states != null && states.isNotEmpty) {
        if (states.length == 1) {
          domain.add(['state', '=', states.first]);
        } else {
          for (int i = 0; i < states.length - 1; i++) {
            domain.add('|');
          }
          for (final state in states) {
            domain.add(['state', '=', state]);
          }
        }
      }

      if (startDate != null) {
        domain.add(['scheduled_date', '>=', startDate.toIso8601String()]);
      }
      if (endDate != null) {
        domain.add(['scheduled_date', '<=', endDate.toIso8601String()]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['origin', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'read_group',
        'args': [domain],
        'kwargs': {
          'fields': ['id'],
          'groupby': [groupByField],
          'lazy': false,
        },
      });

      final groupSummary = <String, int>{};

      if (result is List) {
        for (final group in result) {
          if (group is Map) {
            final groupKey = _getGroupKey(group, groupByField);
            final count = (group['__count'] ?? 0) as int;
            groupSummary[groupKey] = count;
          }
        }
      }

      return groupSummary;
    } catch (e) {
      return {};
    }
  }

  String _getGroupKey(Map group, String groupByField) {
    final value = group[groupByField];
    if (value == null || value == false) {
      return 'Undefined';
    }
    if (value is List && value.length > 1) {
      return value[1].toString();
    }
    return value.toString();
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

  dynamic _extractId(dynamic value) {
    if (value == null) return null;

    if (value is List && value.isNotEmpty) {
      return value[0];
    }

    if (value is String && value.startsWith('[')) {
      try {
        final match = RegExp(r'\[(\d+)').firstMatch(value);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      } catch (e) {}
    }

    return value;
  }

  Future<bool> updateInternalTransfer({
    required int transferId,
    int? locationId,
    int? locationDestId,
    String? scheduledDate,
    List<Map<String, dynamic>>? moveLines,
  }) async {
    try {
      int? pickingCompanyId;
      try {
        final readRes = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'stock.picking',
          'method': 'read',
          'args': [
            [transferId],
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

      final Map<String, dynamic> updateData = {};

      if (locationId != null) updateData['location_id'] = locationId;
      if (locationDestId != null)
        updateData['location_dest_id'] = locationDestId;
      if (scheduledDate != null) {
        updateData['scheduled_date'] = _formatDateTimeForOdoo(scheduledDate);
      }

      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'write',
          'args': [
            [transferId],
            updateData,
          ],
          'kwargs': {},
        },
        companyId: pickingCompanyId,
        allowedCompanyIds: singleAllowed,
      );

      if (moveLines != null && moveLines.isNotEmpty) {
        final session = await OdooSessionManager.getCurrentSession();
        final versionStr = session?.odooSession.serverVersion ?? '16';
        final majorVersion = int.tryParse(versionStr.split('.').first) ?? 16;
        final isOdoo19OrNewer = majorVersion >= 19;
        final moveIdsField = isOdoo19OrNewer
            ? 'move_ids'
            : 'move_ids_without_package';

        final pickingData = await OdooSessionManager.callKwWithCompany(
          {
            'model': 'stock.picking',
            'method': 'read',
            'args': [
              [transferId],
              [moveIdsField],
            ],
            'kwargs': {},
          },
          companyId: pickingCompanyId,
          allowedCompanyIds: singleAllowed,
        );

        if (pickingData is List && pickingData.isNotEmpty) {
          final existingMoveIds = pickingData.first[moveIdsField] as List?;

          if (existingMoveIds != null && existingMoveIds.isNotEmpty) {
            await OdooSessionManager.callKwWithCompany(
              {
                'model': 'stock.move',
                'method': 'unlink',
                'args': [existingMoveIds],
                'kwargs': {},
              },
              companyId: pickingCompanyId,
              allowedCompanyIds: singleAllowed,
            );
          }

          for (final line in moveLines) {
            final productId = _extractId(line['product_id']);
            final productUom = _extractId(line['product_uom']);
            final locId = _extractId(locationId);
            final locDestId = _extractId(locationDestId);

            final session = await OdooSessionManager.getCurrentSession();
            final versionStr = session?.odooSession.serverVersion ?? '16';
            final majorVersion =
                int.tryParse(versionStr.split('.').first) ?? 16;
            final isOdoo19OrNewer = majorVersion >= 19;

            final Map<String, dynamic> moveVals = {
              'picking_id': transferId,
              'product_id': productId,
              'product_uom_qty': line['quantity'],
              'product_uom': productUom,
              'location_id': locId,
              'location_dest_id': locDestId,
              'price_unit': (line['unit_price'] as num?)?.toDouble() ?? 0.0,
            };

            if (!isOdoo19OrNewer) {
              moveVals['name'] = line['product_name'] ?? 'Internal Transfer';
            }

            final moveId = await OdooSessionManager.callKwWithCompany(
              {
                'model': 'stock.move',
                'method': 'create',
                'args': [moveVals],
                'kwargs': {},
              },
              companyId: pickingCompanyId,
              allowedCompanyIds: singleAllowed,
            );
          }
        }
      }

      return result == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> cancelInternalTransfer(int transferId) async {
    try {
      final readRes = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'stock.picking',
        'method': 'read',
        'args': [
          [transferId],
          ['company_id'],
        ],
        'kwargs': {},
      });
      int? companyId;
      if (readRes is List && readRes.isNotEmpty) {
        final item = Map<String, dynamic>.from(readRes.first);
        final cmp = item['company_id'];
        if (cmp is int) {
          companyId = cmp;
        } else if (cmp is List && cmp.isNotEmpty) {
          final first = cmp.first;
          if (first is int) companyId = first;
        }
      }

      final allowed = companyId != null ? [companyId] : <int>[];

      await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'action_cancel',
          'args': [
            [transferId],
          ],
          'kwargs': {},
        },
        companyId: companyId,
        allowedCompanyIds: allowed,
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> markAsTodo(int transferId) async {
    try {
      final readRes = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'stock.picking',
        'method': 'read',
        'args': [
          [transferId],
          ['company_id'],
        ],
        'kwargs': {},
      });

      int? pickingCompanyId;
      if (readRes is List && readRes.isNotEmpty) {
        final item = Map<String, dynamic>.from(readRes.first);
        final company = item['company_id'];
        if (company is int) {
          pickingCompanyId = company;
        } else if (company is List && company.isNotEmpty) {
          final first = company.first;
          if (first is int) pickingCompanyId = first;
        }
      }

      final singleAllowed = pickingCompanyId != null
          ? [pickingCompanyId]
          : <int>[];

      await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'action_confirm',
          'args': [
            [transferId],
          ],
          'kwargs': {},
        },
        companyId: pickingCompanyId,
        allowedCompanyIds: singleAllowed,
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Validates a transfer in Odoo, completing the stock movement.
  Future<bool> validateTransfer(int transferId) async {
    try {
      final readRes = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'stock.picking',
        'method': 'read',
        'args': [
          [transferId],
          ['company_id'],
        ],
        'kwargs': {},
      });
      int? companyId;
      if (readRes is List && readRes.isNotEmpty) {
        final item = Map<String, dynamic>.from(readRes.first);
        final cmp = item['company_id'];
        if (cmp is int) {
          companyId = cmp;
        } else if (cmp is List && cmp.isNotEmpty) {
          final first = cmp.first;
          if (first is int) companyId = first;
        }
      }

      final allowed = companyId != null ? [companyId] : <int>[];

      await OdooSessionManager.callKwWithCompany(
        {
          'model': 'stock.picking',
          'method': 'button_validate',
          'args': [
            [transferId],
          ],
          'kwargs': {},
        },
        companyId: companyId,
        allowedCompanyIds: allowed,
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
