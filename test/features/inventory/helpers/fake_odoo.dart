/// A stand-in for `OdooSessionManager.callKwWithCompany`, answering the
/// calls the product form makes with data shaped like Odoo 20's (checked
/// against a live Odoo 20 server).
class FakeOdoo {
  FakeOdoo({
    this.missingFields = const {},
    this.failRead = false,
    List<Map<String, dynamic>>? categoryOptions,
  }) : categoryOptions =
           categoryOptions ??
           const [
             {'id': 1, 'name': 'Goods', 'complete_name': 'Goods'},
             {'id': 2, 'name': 'Office', 'complete_name': 'Furniture / Office'},
           ];

  /// Fields this "database" does not have (apps not installed).
  final Set<String> missingFields;
  final bool failRead;
  final List<Map<String, dynamic>> categoryOptions;

  final List<Map<String, dynamic>> calls = [];

  /// A 1×1 PNG.
  static const String pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  static const Map<String, Map<String, dynamic>> _fields = {
    'name': {'type': 'char', 'readonly': false, 'required': true},
    'default_code': {'type': 'char', 'readonly': false},
    'barcode': {'type': 'char', 'readonly': false},
    'description_sale': {'type': 'text', 'readonly': false},
    'list_price': {'type': 'float', 'readonly': false},
    'standard_price': {'type': 'float', 'readonly': false},
    'weight': {'type': 'float', 'readonly': false},
    'volume': {'type': 'float', 'readonly': false},
    'sale_delay': {'type': 'integer', 'readonly': false},
    'categ_id': {'type': 'many2one', 'readonly': false},
    'uom_id': {'type': 'many2one', 'readonly': false, 'required': true},
    'currency_id': {'type': 'many2one', 'readonly': true},
    'taxes_id': {'type': 'many2many', 'readonly': false},
    'product_tmpl_id': {'type': 'many2one', 'readonly': false},
    'active': {'type': 'boolean', 'readonly': false},
    'sale_ok': {'type': 'boolean', 'readonly': false},
    'purchase_ok': {'type': 'boolean', 'readonly': false},
    'image_1920': {'type': 'binary', 'readonly': false},
    'is_storable': {'type': 'boolean', 'readonly': false},
  };

  Map<String, dynamic> _fieldsGet() {
    final result = <String, dynamic>{
      for (final e in _fields.entries)
        if (!missingFields.contains(e.key)) e.key: e.value,
    };
    result['type'] = {
      'type': 'selection',
      'readonly': false,
      'required': true,
      // Odoo 18+ has is_storable and no "product" type; earlier releases
      // are the other way round.
      'selection': missingFields.contains('is_storable')
          ? [
              ['consu', 'Consumable'],
              ['service', 'Service'],
              ['product', 'Storable Product'],
            ]
          : [
              ['consu', 'Goods'],
              ['service', 'Service'],
              ['combo', 'Combo'],
            ],
    };
    return result;
  }

  static final Map<String, dynamic> _screw = {
    'id': 74,
    'name': 'Screw',
    'default_code': 'CONS_25630',
    'barcode': '20133785543124',
    'description_sale': false,
    'list_price': 0.2,
    'standard_price': 0.1,
    'weight': 0.01,
    'volume': 0.0,
    'sale_delay': 0,
    'categ_id': [1, 'Goods'],
    'uom_id': [1, 'Units'],
    'currency_id': [1, 'USD'],
    'taxes_id': [1, 8],
    'product_tmpl_id': [56, '[CONS_25630] Screw'],
    'active': true,
    'sale_ok': true,
    'purchase_ok': true,
    'image_1920': {
      'content': pngBase64,
      'size': 68,
      'filename': 'image_1920.png',
    },
  };

  Future<dynamic> call(Map<String, dynamic> payload) async {
    calls.add(payload);
    final model = payload['model'];
    final method = payload['method'];
    final kwargs = (payload['kwargs'] as Map?) ?? const {};

    if (method == 'fields_get') return _fieldsGet();

    if (model == 'product.product' && method == 'read') {
      if (failRead) {
        throw Exception('odoo.exceptions.AccessError: no access');
      }
      final fields = (kwargs['fields'] as List).cast<String>();
      for (final f in fields) {
        if (missingFields.contains(f)) {
          // What Odoo does with a field it does not know.
          throw Exception(
            "ValueError: Invalid field '$f' on model 'product.product'",
          );
        }
      }
      return [
        {
          'id': 74,
          for (final f in fields)
            if (_screw.containsKey(f)) f: _screw[f],
        },
      ];
    }

    if (model == 'product.template' && method == 'default_get') {
      final fields = ((payload['args'] as List).first as List).cast<String>();
      final defaults = <String, dynamic>{
        'uom_id': 1,
        'taxes_id': [
          [
            6,
            0,
            [1, 8],
          ],
        ],
        'sale_ok': true,
        'purchase_ok': true,
        'list_price': 1.0,
        'active': true,
      };
      return {
        for (final f in fields)
          if (defaults.containsKey(f)) f: defaults[f],
      };
    }

    if (method == 'search_read') {
      switch (model) {
        case 'product.category':
          return categoryOptions;
        case 'uom.uom':
          return [
            {'id': 1, 'name': 'Units'},
            {'id': 12, 'name': 'kg'},
          ];
        case 'res.currency':
          return [
            {'id': 1, 'name': 'USD', 'symbol': r'$'},
            {'id': 2, 'name': 'EUR', 'symbol': '€'},
          ];
        case 'account.tax':
          return [
            {'id': 1, 'name': '15%', 'amount': 15.0},
          ];
      }
      return [];
    }

    if (model == 'account.tax' && method == 'read') {
      final ids = ((payload['args'] as List).first as List).cast<int>();
      return [
        for (final id in ids) {'id': id, 'name': 'Tax $id', 'amount': 5.0},
      ];
    }

    if (method == 'write') return true;
    if (method == 'create') return 900;

    throw UnimplementedError('$model.$method');
  }
}
