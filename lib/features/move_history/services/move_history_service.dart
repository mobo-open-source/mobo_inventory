import '../../../core/odoo/odoo_read_group.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/move_history_item.dart';

class MoveHistoryService {
  /// The `stock.move.line` domain for the History filters, in Odoo's prefix
  /// notation. Shared by the list, its count and its groups, so a group's
  /// count matches the records it opens.
  static List<dynamic> buildDomain({
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
  }) {
    final List<dynamic> domain = [];

    if (activeOnly) {
      domain.add([
        'move_id.state',
        'not in',
        ['done', 'draft', 'cancel'],
      ]);
    } else if (status != null && status.isNotEmpty) {
      domain.add(['move_id.state', '=', status]);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // `reference` (the move's) rather than `move_id.name`, which Odoo 19
      // dropped.
      domain.addAll([
        '|',
        ['product_id', 'ilike', searchQuery],
        ['reference', 'ilike', searchQuery],
      ]);
    }

    if (pickingTypeCodes != null && pickingTypeCodes.isNotEmpty) {
      for (var i = 0; i < pickingTypeCodes.length - 1; i++) {
        domain.add('|');
      }
      for (final code in pickingTypeCodes) {
        domain.add(['picking_id.picking_type_id.code', '=', code]);
      }
    }

    if (dateFrom != null) domain.add(['date', '>=', _fmt(dateFrom)]);
    if (dateTo != null) domain.add(['date', '<=', _fmt(dateTo)]);

    if (inventoryOnly) domain.add(['move_id.is_inventory', '=', true]);

    return domain;
  }

  static String _fmt(DateTime d) {
    final dt = d.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  /// The `stock.move.line` fields each History group-by groups on. Where a
  /// release names a field differently, the candidates are tried in turn:
  /// the product category is the stored `product_category_name` up to Odoo
  /// 19, and only the related `product_category_id` on Odoo 20.
  static const Map<String, List<List<String>>> _groupFields = {
    'product': [
      ['product_id'],
    ],
    'state': [
      ['state'],
    ],
    'location': [
      ['location_id', 'location_dest_id'],
    ],
    'category': [
      ['product_category_name'],
      ['product_category_id'],
    ],
    'transfer': [
      ['picking_id'],
    ],
  };

  static const Map<String, String> statusLabels = {
    'draft': 'New',
    'waiting': 'Waiting Another Move',
    'confirmed': 'Waiting Availability',
    'partially_available': 'Partially Available',
    'assigned': 'Available',
    'done': 'Done',
    'cancel': 'Cancelled',
  };

  /// Counts the move lines of each group under the History filters, the
  /// way Odoo's grouped list does, keyed by the group's label in Odoo's
  /// order. [domainsOut] receives each group's own domain, for
  /// [fetchHistory]'s `domainOverride`.
  Future<Map<String, int>> fetchGroupSummary({
    required String groupBy,
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
    Map<String, List<dynamic>>? domainsOut,
  }) async {
    final domain = buildDomain(
      searchQuery: searchQuery,
      dateFrom: dateFrom,
      dateTo: dateTo,
      status: status,
      pickingTypeCodes: pickingTypeCodes,
      activeOnly: activeOnly,
      inventoryOnly: inventoryOnly,
    );
    // A date group-by (`date:day`, `date:month`, ...) is passed through.
    final candidates =
        _groupFields[groupBy] ??
        [
          [groupBy],
        ];

    Object? lastError;
    for (final fields in candidates) {
      try {
        final rows = await OdooReadGroup.countsBy(
          model: 'stock.move.line',
          domain: domain,
          groupBy: fields,
        );
        final summary = <String, int>{};
        for (final row in rows) {
          var label = _groupLabel(groupBy, fields, row);
          // Two groups of the same name (e.g. two products) stay apart.
          for (var n = 2; summary.containsKey(label); n++) {
            label = '${_groupLabel(groupBy, fields, row)} ($n)';
          }
          summary[label] = (row['__count'] as num?)?.toInt() ?? 0;
          final groupDomain = row['__domain'];
          domainsOut?[label] = groupDomain is List
              ? List<dynamic>.from(groupDomain)
              : [
                  ...domain,
                  for (final field in fields) [field, '=', row[field] ?? false],
                ];
        }
        return summary;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('No field to group by $groupBy');
  }

  static String _groupLabel(
    String groupBy,
    List<String> fields,
    Map<String, dynamic> row,
  ) {
    String name(dynamic value) {
      if (value == null || value == false) return 'None';
      if (value is List && value.length > 1) return value[1].toString();
      return value.toString();
    }

    if (groupBy == 'location') {
      return '${name(row[fields[0]])} → ${name(row[fields[1]])}';
    }
    final value = row[fields.first];
    if (groupBy == 'state' && value is String) {
      return statusLabels[value] ?? value;
    }
    return name(value);
  }

  Future<List<MoveHistoryItem>> fetchHistory({
    int offset = 0,
    int limit = 20,
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
    // A group's own domain from [fetchGroupSummary]; replaces the filters.
    List<dynamic>? domainOverride,
  }) async {
    try {
      await OdooSessionManager.getClientEnsured();

      final domain =
          domainOverride ??
          buildDomain(
            searchQuery: searchQuery,
            dateFrom: dateFrom,
            dateTo: dateTo,
            status: status,
            pickingTypeCodes: pickingTypeCodes,
            activeOnly: activeOnly,
            inventoryOnly: inventoryOnly,
          );

      dynamic result;
      try {
        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': [
              'id',
              'date',
              'state',
              'quantity',
              'product_id',
              'lot_id',
              'location_id',
              'location_dest_id',
              'move_id',
              'picking_id',
            ],
            'offset': offset,
            'limit': limit,
            'order': 'date desc, id desc',
            'context': {'lang': 'en_US', 'tz': 'Asia/Calcutta'},
          },
        });
      } catch (e) {
        // A group's records come from its own domain or not at all.
        if (domainOverride != null) rethrow;

        final List<dynamic> simpleDomain = [];
        if (activeOnly) {
          simpleDomain.add([
            'state',
            'not in',
            ['done', 'draft', 'cancel'],
          ]);
        } else if (status != null && status.isNotEmpty) {
          simpleDomain.add(['state', '=', status]);
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          simpleDomain.add(['product_id', 'ilike', searchQuery]);
        }

        if (inventoryOnly)
          simpleDomain.add(['move_id.is_inventory', '=', true]);

        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_read',
          'args': [simpleDomain],
          'kwargs': {
            'fields': [
              'id',
              'date',
              'state',
              'quantity',
              'product_id',
              'lot_id',
              'location_id',
              'location_dest_id',
              'move_id',
            ],
            'offset': offset,
            'limit': limit,
            'order': 'date desc, id desc',
            'context': {'lang': 'en_US', 'tz': 'Asia/Calcutta'},
          },
        });
      }

      if (result is List) {
        var items = result
            .cast<Map<String, dynamic>>()
            .map((e) => MoveHistoryItem.fromJson(e))
            .toList();

        final locIds = <int>{};
        for (final it in items) {
          if (it.fromLocationId != null) locIds.add(it.fromLocationId!);
          if (it.toLocationId != null) locIds.add(it.toLocationId!);
        }
        Map<int, String> usageById = {};
        if (locIds.isNotEmpty) {
          try {
            final locs = await OdooSessionManager.callKwWithCompany({
              'model': 'stock.location',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', locIds.toList()],
                ],
              ],
              'kwargs': {
                'fields': ['id', 'usage'],
                'limit': locIds.length,
              },
            });
            if (locs is List) {
              for (final m in locs.cast<Map<String, dynamic>>()) {
                final id = m['id'] as int?;
                final usage = m['usage']?.toString();
                if (id != null && usage != null) usageById[id] = usage;
              }
            }
          } catch (e) {}
        }

        bool isInternal(String? u) => u == 'internal' || u == 'transit';
        items = items.map((it) {
          final fromUsage = usageById[it.fromLocationId ?? -1];
          final toUsage = usageById[it.toLocationId ?? -1];
          int sign = 0;
          if (isInternal(toUsage)) sign += 1;
          if (isInternal(fromUsage)) sign -= 1;
          final signedQty = sign == 0 ? it.quantity : (it.quantity * sign);
          return it.copyWith(quantity: signedQty);
        }).toList();

        final productIds = <int>{};
        for (final it in items) {
          if (it.productId != null) productIds.add(it.productId!);
        }
        if (productIds.isNotEmpty) {
          try {
            final prods = await OdooSessionManager.callKwWithCompany({
              'model': 'product.product',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', productIds.toList()],
                ],
              ],
              'kwargs': {
                'fields': ['id', 'categ_id'],
                'limit': productIds.length,
              },
            });
            final catByProd = <int, String>{};
            if (prods is List) {
              for (final m in prods.cast<Map<String, dynamic>>()) {
                final pid = m['id'] as int?;
                final c = m['categ_id'];
                String? cname;
                if (c is List && c.isNotEmpty) {
                  cname = c.length > 1 ? c[1].toString() : null;
                } else if (c is Map<String, dynamic>) {
                  cname = c['display_name']?.toString();
                }
                if (pid != null && cname != null) catByProd[pid] = cname;
              }
            }
            if (catByProd.isNotEmpty) {
              items = items
                  .map(
                    (it) =>
                        it.productId != null &&
                            catByProd.containsKey(it.productId!)
                        ? it.copyWith(productCategory: catByProd[it.productId!])
                        : it,
                  )
                  .toList();
            }
          } catch (e) {}
        }

        return items;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getHistoryCount({
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
  }) async {
    try {
      await OdooSessionManager.getClientEnsured();

      final domain = buildDomain(
        searchQuery: searchQuery,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        pickingTypeCodes: pickingTypeCodes,
        activeOnly: activeOnly,
        inventoryOnly: inventoryOnly,
      );

      dynamic result;
      try {
        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {
            'context': {'lang': 'en_US', 'tz': 'Asia/Calcutta'},
          },
        });
      } catch (e) {
        final List<dynamic> simpleDomain = [];
        if (activeOnly) {
          simpleDomain.add([
            'state',
            'not in',
            ['done', 'draft', 'cancel'],
          ]);
        } else if (status != null && status.isNotEmpty) {
          simpleDomain.add(['state', '=', status]);
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          simpleDomain.add(['product_id', 'ilike', searchQuery]);
        }

        if (inventoryOnly)
          simpleDomain.add(['move_id.is_inventory', '=', true]);

        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_count',
          'args': [simpleDomain],
          'kwargs': {
            'context': {'lang': 'en_US', 'tz': 'Asia/Calcutta'},
          },
        });
      }

      return result is int ? result : 0;
    } catch (e) {
      return 0;
    }
  }
}
