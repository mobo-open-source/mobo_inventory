import '../services/odoo_session_manager.dart';
import 'odoo_compat.dart';

/// Counts records per group on every supported Odoo release.
///
/// Up to 19 this is `read_group(domain, fields, groupby, lazy: false)`. Odoo 20
/// gave `read_group` a new signature and tuple results, so there the counts
/// come from `formatted_read_group` instead and are reshaped into the rows the
/// callers already read.
class OdooReadGroup {
  OdooReadGroup._();

  /// `fields_get` types, keyed `model|field`, for the date check below.
  static final Map<String, String?> _fieldTypes = {};

  /// Rows shaped like a `lazy: false` `read_group`:
  /// `{groupBy: value, '__count': int, '__domain': List}`.
  ///
  /// Many2one values are `[id, name]`. On Odoo 20 a date group's value is
  /// `[rangeStart, label]` rather than the bare label, so callers should read
  /// the label from index 1 of a list (as they already do for many2one).
  static Future<List<Map<String, dynamic>>> counts({
    required String model,
    required List<dynamic> domain,
    required String groupBy,
    Map<String, dynamic>? context,
  }) => countsBy(
    model: model,
    domain: domain,
    groupBy: [groupBy],
    context: context,
  );

  /// [counts] grouped by several fields at once (one row per combination,
  /// as `read_group(..., lazy: false)` gives): each row carries a value for
  /// every field in [groupBy].
  static Future<List<Map<String, dynamic>>> countsBy({
    required String model,
    required List<dynamic> domain,
    required List<String> groupBy,
    Map<String, dynamic>? context,
  }) async {
    final compat = await OdooCompat.current();

    if (compat.hasLegacyReadGroup) {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': 'read_group',
        'args': [domain],
        'kwargs': {
          'fields': ['id'],
          'groupby': groupBy,
          'lazy': false,
          if (context != null) 'context': context,
        },
      });
      if (result is! List) return const [];
      return [
        for (final row in result)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    }

    // Odoo 20 refuses a date(time) groupby without a granularity; the old
    // read_group grouped those by month.
    final specs = <String, String>{
      for (final field in groupBy)
        field: await _isDateField(model, field, context)
            ? '$field:month'
            : field,
    };

    final result = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'formatted_read_group',
      'args': [domain],
      'kwargs': {
        'groupby': specs.values.toList(),
        'aggregates': ['__count'],
        if (context != null) 'context': context,
      },
    });
    if (result is! List) return const [];
    return [
      for (final row in result)
        if (row is Map)
          {
            for (final entry in specs.entries) entry.key: row[entry.value],
            '__count': row['__count'],
            // Two well-formed domains concatenated are AND-ed.
            '__domain': [
              ...domain,
              ...(row['__extra_domain'] is List
                  ? row['__extra_domain'] as List
                  : const []),
            ],
          },
    ];
  }

  static Future<bool> _isDateField(
    String model,
    String field,
    Map<String, dynamic>? context,
  ) async {
    // A related path (`product_id.categ_id`) is never a date in this app.
    if (field.contains('.') || field.contains(':')) return false;
    final key = '$model|$field';
    if (!_fieldTypes.containsKey(key)) {
      try {
        final res = await OdooSessionManager.callKwWithCompany({
          'model': model,
          'method': 'fields_get',
          'args': [
            [field],
          ],
          'kwargs': {
            'attributes': ['type'],
            if (context != null) 'context': context,
          },
        });
        final desc = res is Map ? res[field] : null;
        _fieldTypes[key] = desc is Map ? desc['type']?.toString() : null;
      } catch (_) {
        // Unknown: let formatted_read_group report its own error.
        return false;
      }
    }
    final type = _fieldTypes[key];
    return type == 'date' || type == 'datetime';
  }
}
