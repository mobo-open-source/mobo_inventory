class Warehouse {
  final int id;
  final String name;
  final String? code;
  final String? companyName;
  final int? lotStockId;
  final String? lotStockName;

  Warehouse({
    required this.id,
    required this.name,
    this.code,
    this.companyName,
    this.lotStockId,
    this.lotStockName,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    String? company;
    final companyField = json['company_id'];
    if (companyField is List && companyField.length > 1) {
      company = companyField[1]?.toString();
    } else if (companyField is Map) {
      company = (companyField['display_name'] ?? companyField['name'])
          ?.toString();
    }

    int? lotStockId;
    String? lotStockName;
    final lotStock = json['lot_stock_id'];
    if (lotStock is List && lotStock.length > 1) {
      lotStockId = lotStock[0] as int?;
      lotStockName = lotStock[1]?.toString();
    } else if (lotStock is Map) {
      lotStockId = lotStock['id'] as int?;
      lotStockName = (lotStock['display_name'] ?? lotStock['name'])?.toString();
    }

    return Warehouse(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      companyName: company,
      lotStockId: lotStockId,
      lotStockName: lotStockName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'company_id': companyName != null ? [0, companyName] : null,
      'lot_stock_id': lotStockId != null ? [lotStockId, lotStockName] : null,
    };
  }
}
