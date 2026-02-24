class StockLocation {
  final int id;
  final String name;
  final String? completeName;
  final String usage;
  final int? parentId;
  final String? parentName;

  StockLocation({
    required this.id,
    required this.name,
    required this.usage,
    this.completeName,
    this.parentId,
    this.parentName,
  });

  factory StockLocation.fromJson(Map<String, dynamic> json) {
    int? parentId;
    String? parentName;
    final parent = json['location_id'];
    if (parent is List && parent.length > 1) {
      parentId = parent[0] as int?;
      parentName = parent[1]?.toString();
    } else if (parent is Map) {
      parentId = parent['id'] as int?;
      parentName = (parent['display_name'] ?? parent['name'])?.toString();
    }

    return StockLocation(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      completeName: (json['complete_name'] ?? '').toString().isEmpty
          ? null
          : (json['complete_name'] ?? '').toString(),
      usage: (json['usage'] ?? 'internal').toString(),
      parentId: parentId,
      parentName: parentName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'complete_name': completeName,
      'usage': usage,
      'location_id': parentId != null ? [parentId, parentName] : null,
    };
  }
}
