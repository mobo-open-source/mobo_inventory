class Picking {
  final int id;
  final String name;
  final String state;
  final String? origin;
  final String? partnerName;
  final String pickingTypeCode;
  final String pickingTypeName;
  final String scheduledDate;

  Picking({
    required this.id,
    required this.name,
    required this.state,
    required this.pickingTypeCode,
    required this.pickingTypeName,
    required this.scheduledDate,
    this.origin,
    this.partnerName,
  });

  factory Picking.fromJson(Map<String, dynamic> json) {
    String? partner;
    final partnerField = json['partner_id'];
    if (partnerField is List && partnerField.length > 1) {
      partner = partnerField[1]?.toString();
    } else if (partnerField is Map) {
      partner = (partnerField['display_name'] ?? partnerField['name'])
          ?.toString();
    }

    String pickingTypeName = '';
    final pt = json['picking_type_id'];
    if (pt is List && pt.length > 1) {
      pickingTypeName = pt[1]?.toString() ?? '';
    }
    if (pt is Map) {
      pickingTypeName = (pt['display_name'] ?? pt['name'])?.toString() ?? '';
    }

    return Picking(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      pickingTypeCode: (json['picking_code'] ?? json['picking_type_code'] ?? '')
          .toString(),
      pickingTypeName: pickingTypeName,
      scheduledDate: (json['scheduled_date'] ?? json['date'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      partnerName: partner,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'picking_type_code': pickingTypeCode,
      'picking_type_id': [0, pickingTypeName],
      'scheduled_date': scheduledDate,
      'origin': origin,
      'partner_id': partnerName != null ? [0, partnerName] : null,
    };
  }
}
