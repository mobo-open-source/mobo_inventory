import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/odoo/odoo_compat.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/transfer_model.dart';
import '../utils/transfer_state_helper.dart';
import '../../../core/odoo/odoo_read_group.dart';

/// One group of a server-side group-by: a readable [label], how many
/// transfers it holds, and the Odoo [domain] that selects exactly them.
class TransferGroup {
  final String label;
  final int count;
  final List<dynamic> domain;

  const TransferGroup({
    required this.label,
    required this.count,
    required this.domain,
  });
}

/// Service for interacting with Odoo's `stock.picking` and `stock.move` models.
class TransferService {
  /// Checks whether an "Internal Transfer" operation type is available to
  /// use. Returns `null` when one is active and ready, or a user-facing
  /// message explaining why not otherwise.
  ///
  /// A plain domain search on `stock.picking.type` silently excludes
  /// archived records (Odoo's implicit `active = True` filter), so a naive
  /// existence check would just see "not found" either way. `active_test:
  /// false` bypasses that filter so we can look ourselves — but either way
  /// (missing entirely, or present but archived) traces back to the same
  /// cause: Odoo only keeps an active "Internal Transfers" type while the
  /// warehouse's "Storage Locations" setting is on, and archives it (rather
  /// than deleting it) the moment that setting is switched off. So both
  /// cases get the same fix: turn that setting back on.
  Future<String?> checkInternalOperationTypeStatus() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking.type',
        'method': 'search_read',
        'args': [
          [
            ['code', '=', 'internal'],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'active'],
          'context': {'active_test': false},
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      final hasActive = list.any((r) => r['active'] == true);
      if (!hasActive) {
        return 'Internal transfers require the "Storage Locations" setting '
            'to be enabled. Go to Inventory > Configuration > Settings and '
            'turn on Storage Locations to access internal transfers.';
      }

      return null;
    } catch (e) {
      // Don't block on a failed lookup — let the real fetch below surface
      // its own error rather than guessing at one here.
      return null;
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
    // A group's own domain from [fetchGroups]; replaces the filters above.
    List<dynamic>? domainOverride,
  }) async {
    try {
      List<dynamic> domain = [
        ['picking_type_code', '=', 'internal'],
      ];
      if (domainOverride != null) domain = List<dynamic>.from(domainOverride);

      if (domainOverride == null && states != null && states.isNotEmpty) {
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

      if (domainOverride == null && startDate != null) {
        domain.add(['scheduled_date', '>=', startDate.toIso8601String()]);
      }
      if (domainOverride == null && endDate != null) {
        domain.add(['scheduled_date', '<=', endDate.toIso8601String()]);
      }

      if (domainOverride == null &&
          searchQuery != null &&
          searchQuery.isNotEmpty) {
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
      final moveIdsField = (await OdooCompat.current()).pickingMoveIdsField;

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
          final compat = await OdooCompat.current();
          final movesResult = await OdooSessionManager.callKwWithCompany({
            'model': 'stock.move',
            'method': 'read',
            'args': [
              moveIds,
              [
                'id',
                'product_id',
                'product_uom_qty',
                compat.stockMoveUomField,
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

  Future<List<TransferGroup>> fetchGroupSummary({
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

      // "Date" groups by stock.picking.date, which Odoo 19 removed; from 19
      // on the same grouping is by scheduled_date.
      final compat = await OdooCompat.current();
      final field = groupByField == 'date' && !compat.pickingHasDateField
          ? 'scheduled_date'
          : groupByField;

      final result = await OdooReadGroup.counts(
        model: 'stock.picking',
        domain: domain,
        groupBy: field,
      );

      final groups = <TransferGroup>[];

      for (final group in result) {
        final rawDomain = group['__domain'];
        groups.add(
          TransferGroup(
            label: _groupLabel(group[field], groupByField),
            count: (group['__count'] as num?)?.toInt() ?? 0,
            // Odoo's own domain for this group: the filters above plus
            // this group's value, so its rows are exactly its count.
            domain: rawDomain is List
                ? List<dynamic>.from(rawDomain)
                : [
                    ...domain,
                    [field, '=', group[field] ?? false],
                  ],
          ),
        );
      }

      return groups;
    } catch (e) {
      return [];
    }
  }

  /// What a group is called on screen. Odoo returns selection fields as
  /// their raw key — priority `'0'` / `'1'`, state `'assigned'` — which
  /// meant nothing to a user.
  String _groupLabel(dynamic value, String groupByField) {
    if (value == null || value == false) {
      switch (groupByField) {
        case 'date':
        case 'scheduled_date':
          return 'No Date';
        case 'priority':
          return 'Normal';
        default:
          return 'Not Set';
      }
    }
    if (value is List && value.length > 1) {
      return value[1].toString();
    }
    switch (groupByField) {
      case 'priority':
        return value.toString() == '1' ? 'Urgent' : 'Normal';
      case 'state':
        return TransferStateHelper.getStateLabel(value.toString());
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

  /// Reads a stock.location's company_id without any company-context
  /// restriction, so a location belonging to a company outside the
  /// currently active one can still be looked up (needed to build a
  /// correct `allowed_company_ids` list for the calls that follow).
  Future<int?> fetchLocationCompanyId(int? locationId) async {
    if (locationId == null) return null;
    try {
      final res = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'stock.location',
        'method': 'read',
        'args': [
          [locationId],
          ['company_id'],
        ],
        'kwargs': {},
      });
      if (res is List && res.isNotEmpty) {
        final cmp = Map<String, dynamic>.from(res.first)['company_id'];
        if (cmp is int) return cmp;
        if (cmp is List && cmp.isNotEmpty) return cmp.first as int?;
      }
    } catch (_) {}
    return null;
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

      final srcCompanyId = await fetchLocationCompanyId(locationId);
      final dstCompanyId = await fetchLocationCompanyId(locationDestId);

      final singleAllowed = <int>{
        if (pickingCompanyId != null) pickingCompanyId,
        if (srcCompanyId != null) srcCompanyId,
        if (dstCompanyId != null) dstCompanyId,
      }.toList();

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
        final moveIdsField = (await OdooCompat.current()).pickingMoveIdsField;

        final pickingData = await OdooSessionManager.callKwWithCompany(
          {
            'model': 'stock.picking',
            'method': 'read',
            'args': [
              [transferId],
              [moveIdsField, 'scheduled_date'],
            ],
            'kwargs': {},
          },
          companyId: pickingCompanyId,
          allowedCompanyIds: singleAllowed,
        );

        if (pickingData is List && pickingData.isNotEmpty) {
          final pickingRecord = Map<String, dynamic>.from(
            pickingData.first as Map,
          );
          final existingMoveIds = pickingRecord[moveIdsField] as List?;

          // stock.picking.scheduled_date is a stored compute derived from
          // its moves' `date`. Recreating the moves below without carrying
          // this forward makes Odoo recompute it from the new moves'
          // default date (effectively "now"), silently reverting whatever
          // date the write above just set — even on edits that never
          // touched the date. Resolve the value to stamp on the new moves
          // once, preferring the newly requested date.
          final existingScheduledDate = pickingRecord['scheduled_date'];
          final moveDate = scheduledDate != null
              ? _formatDateTimeForOdoo(scheduledDate)
              : (existingScheduledDate is String
                    ? existingScheduledDate
                    : null);

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

          final compat = await OdooCompat.current();

          for (final line in moveLines) {
            final productId = _extractId(line['product_id']);
            final productUom = _extractId(line['product_uom']);
            final locId = _extractId(locationId);
            final locDestId = _extractId(locationDestId);

            final Map<String, dynamic> moveVals = {
              'picking_id': transferId,
              'product_id': productId,
              'product_uom_qty': line['quantity'],
              compat.stockMoveUomField: productUom,
              'location_id': locId,
              'location_dest_id': locDestId,
              'price_unit': (line['unit_price'] as num?)?.toDouble() ?? 0.0,
              if (moveDate != null) 'date': moveDate,
            };

            if (compat.stockMoveHasName) {
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
          'kwargs': {
            'context': (await OdooCompat.current()).confirmPickingContext,
          },
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
      final compat = await OdooCompat.current();
      final context = compat.confirmPickingContext;

      Future<dynamic> call(
        String model,
        String method,
        List<dynamic> args, [
        Map<String, dynamic> kwargs = const {},
      ]) => OdooSessionManager.callKwWithCompany(
        {'model': model, 'method': method, 'args': args, 'kwargs': kwargs},
        companyId: companyId,
        allowedCompanyIds: allowed,
      );

      // Odoo 17+ validates only each move's `quantity`, so a transfer with
      // nothing reserved fails with "Validating a zero quantity transfer?".
      // Reserve what is on hand, then fill the rest up to the demand — what
      // Odoo's own `button_validate` does for a draft transfer — so Validate
      // completes the whole transfer as the confirm dialog says.
      await call(
        'stock.picking',
        'action_assign',
        [
          [transferId],
        ],
        {'context': context},
      );

      final moveIdsField = compat.pickingMoveIdsField;
      final pickingRes = await call('stock.picking', 'read', [
        [transferId],
        [moveIdsField],
      ]);
      final moveIds = pickingRes is List && pickingRes.isNotEmpty
          ? pickingRes.first[moveIdsField]
          : null;

      if (moveIds is List && moveIds.isNotEmpty) {
        final qtyField = compat.stockMoveQuantityField;
        final moves = await call('stock.move', 'read', [
          moveIds,
          [
            'state',
            'product_uom_qty',
            qtyField,
            if (compat.stockMoveHasPicked) 'picked',
          ],
        ]);
        if (moves is List) {
          for (final move in moves.cast<Map<String, dynamic>>()) {
            if (move['state'] == 'done' || move['state'] == 'cancel') continue;
            final demand = (move['product_uom_qty'] as num?) ?? 0;
            final quantity = (move[qtyField] as num?) ?? 0;
            if (demand <= 0 && quantity <= 0) continue;

            final vals = <String, dynamic>{
              if (quantity < demand) qtyField: demand,
              if (compat.stockMoveHasPicked && move['picked'] != true)
                'picked': true,
            };
            if (vals.isNotEmpty) {
              await call('stock.move', 'write', [
                [move['id']],
                vals,
              ]);
            }
          }
        }
      }

      final result = await call(
        'stock.picking',
        'button_validate',
        [
          [transferId],
        ],
        {'context': context},
      );

      // A window action means Odoo stopped to ask something (backorder,
      // expired lots, quality checks…) and the transfer is not done yet.
      if (result is Map && result['type'] == 'ir.actions.act_window') {
        final step = result['name']?.toString();
        throw ValidationException(
          'Odoo needs another confirmation to finish this transfer'
          '${step != null && step.isNotEmpty ? ' ($step)' : ''}. '
          'Please complete it in Odoo.',
        );
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
