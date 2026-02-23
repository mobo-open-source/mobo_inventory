class ReplenishmentOrderpoint {
  final int id;
  final int? productId;
  final String productName;
  final int? locationId;
  final String locationName;
  final double onHand;
  final double forecast;
  final double minQty;
  final double maxQty;
  final double toOrder;
  final String trigger;
  final bool snoozed;
  final DateTime? snoozedUntil;

  ReplenishmentOrderpoint({
    required this.id,
    required this.productId,
    required this.productName,
    required this.locationId,
    required this.locationName,
    required this.onHand,
    required this.forecast,
    required this.minQty,
    required this.maxQty,
    required this.toOrder,
    required this.trigger,
    required this.snoozed,
    this.snoozedUntil,
  });

  factory ReplenishmentOrderpoint.fromJson(Map<String, dynamic> json) {
    List asList(dynamic v) => (v is List)
        ? v
        : (v is Map ? [v['id'], v['display_name'] ?? v['name']] : []);
    String display(List l) => l.length > 1 ? (l[1]?.toString() ?? '') : '';
    double d(dynamic v) {
      if (v == null || v == false) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final prod = asList(json['product_id']);
    final loc = asList(json['location_id']);

    DateTime? parseDate(dynamic v) {
      if (v == null || v == false) return null;
      final s = v.toString();
      try {

        if (s.length == 10 && s.contains('-')) {
          return DateTime.parse(s);
        }
        return DateTime.tryParse(s);
      } catch (_) {
        return null;
      }
    }

    final DateTime? snoozedUntil = parseDate(json['snoozed_until']);
    final bool isSnoozed =
        snoozedUntil != null && snoozedUntil.isAfter(DateTime.now());

    return ReplenishmentOrderpoint(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      productId: prod.isNotEmpty
          ? (prod[0] is int ? prod[0] as int : int.tryParse('${prod[0]}'))
          : null,
      productName: display(prod),
      locationId: loc.isNotEmpty
          ? (loc[0] is int ? loc[0] as int : int.tryParse('${loc[0]}'))
          : null,
      locationName: display(loc),
      onHand: d(json['qty_on_hand'] ?? json['qty_available']),
      forecast: d(json['qty_forecast'] ?? json['virtual_available']),
      minQty: d(json['product_min_qty']),
      maxQty: d(json['product_max_qty']),
      toOrder: d(json['qty_to_order'] ?? json['qty_to_order_manual']),
      trigger: (json['trigger']?.toString() ?? '').trim(),
      snoozed: isSnoozed,
      snoozedUntil: snoozedUntil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId != null ? [productId, productName] : false,
      'location_id': locationId != null ? [locationId, locationName] : false,
      'qty_on_hand': onHand,
      'qty_forecast': forecast,
      'product_min_qty': minQty,
      'product_max_qty': maxQty,
      'qty_to_order': toOrder,
      'trigger': trigger,
      'snoozed_until': snoozedUntil?.toIso8601String(),
    };
  }
}
