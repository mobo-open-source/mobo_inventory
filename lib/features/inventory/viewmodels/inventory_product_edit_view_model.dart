import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/utils/base64_utils.dart';

/// One Odoo `call_kw` round trip; [OdooSessionManager.callKwWithCompany] in
/// the app, a fake in tests.
typedef OdooCallKw = Future<dynamic> Function(Map<String, dynamic> payload);

/// Backs the product form, both for editing an existing `product.product`
/// ([load]) and for creating a new `product.template` ([initCreate]).
///
/// Every read and write is checked against the server's `fields_get` first.
/// Several fields the form shows come from apps an Inventory-only database
/// does not have — `taxes_id` (Invoicing/`account`) and `sale_delay`
/// (Sales) — and naming a missing field makes Odoo reject the whole call.
/// The form used to read them unconditionally, so on such a database the
/// read failed, the error was swallowed and the edit form opened blank.
class InventoryProductEditViewModel extends ChangeNotifier {
  InventoryProductEditViewModel({OdooCallKw? callKw})
    : _callKw = callKw ?? OdooSessionManager.callKwWithCompany;

  final OdooCallKw _callKw;

  String name = '';
  String sku = '';
  String barcode = '';
  String description = '';
  double? listPrice;
  double? standardPrice;
  double? weight;
  double? volume;
  String dimensions = '';
  double? leadTime;
  int? categId;
  int? uomId;
  int? currencyId;
  List<int> taxes = [];
  bool isActive = true;
  bool saleOk = true;
  bool purchaseOk = true;
  String? imageBase64;

  /// Whether a new product tracks its stock (Odoo 18+ `is_storable`, or the
  /// "Storable Product" type before that). Only sent on create.
  bool trackInventory = true;

  /// The `product.product` being edited; null in create mode.
  int? productId;
  int? templateId;

  /// The `product.template` id [save] created, in create mode.
  int? createdTemplateId;

  List<Map<String, String>> categoryOptions = [];
  List<Map<String, String>> taxOptions = [];
  List<Map<String, String>> uomOptions = [];
  List<Map<String, String>> currencyOptions = [];

  bool loading = true;
  bool saving = false;
  String? error;

  /// True once [load] has read the product (edit mode) or [initCreate] has
  /// set up a blank one (create mode). The screen shows the form only then;
  /// otherwise it shows [error] with a retry instead of an empty form that
  /// looks like "create new".
  bool recordLoaded = false;

  bool get isCreateMode => productId == null;

  /// `fields_get` of the model the form reads/creates, keyed by field name.
  /// Null until fetched, or if fetching it failed.
  Map<String, dynamic>? _fieldsInfo;

  bool get hasTaxesField => _hasField('taxes_id');

  /// Whether the server can mark a new product as tracking its stock.
  bool get canTrackInventory =>
      _hasField('is_storable') || _typeSelection.contains('product');

  List<String> get _typeSelection {
    final type = _fieldsInfo?['type'];
    final selection = type is Map ? type['selection'] : null;
    return [
      if (selection is List)
        for (final option in selection)
          if (option is List && option.isNotEmpty) option.first.toString(),
    ];
  }

  // Labels of the record's many2one values, for when the record's value is
  // not among the options fetched for a dropdown (they are capped).
  String? _categLabel;
  String? _uomLabel;
  String? _currencyLabel;

  Uint8List? _imageBytes;
  String? _imageBytesSource;

  /// [imageBase64] decoded once, rather than on every rebuild of the form
  /// (which would also hand the image widget a new provider each keystroke).
  Uint8List? get imageBytes {
    final b64 = imageBase64;
    if (b64 == null || b64.isEmpty) return null;
    if (_imageBytesSource != b64) {
      _imageBytesSource = b64;
      try {
        _imageBytes = base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
      } catch (_) {
        _imageBytes = null;
      }
    }
    return _imageBytes;
  }

  String _origName = '';
  String _origSku = '';
  String _origBarcode = '';
  String _origDescription = '';
  double? _origListPrice;
  double? _origStandardPrice;
  double? _origWeight;
  double? _origVolume;
  double? _origLeadTime;
  int? _origCategId;
  int? _origUomId;
  int? _origCurrencyId;
  List<int> _origTaxes = const [];
  bool _origIsActive = true;
  bool _origSaleOk = true;
  bool _origPurchaseOk = true;
  String? _origImageBase64;
  bool _origTrackInventory = true;

  bool get hasUnsavedChanges {
    if (name != _origName) return true;
    if (sku != _origSku) return true;
    if (barcode != _origBarcode) return true;
    if (description != _origDescription) return true;
    if (!_doubleEquals(listPrice, _origListPrice)) return true;
    if (!_doubleEquals(standardPrice, _origStandardPrice)) return true;
    if (!_doubleEquals(weight, _origWeight)) return true;
    if (!_doubleEquals(volume, _origVolume)) return true;
    if (!_doubleEquals(leadTime, _origLeadTime)) return true;
    if (categId != _origCategId) return true;
    if (uomId != _origUomId) return true;
    if (currencyId != _origCurrencyId) return true;
    if (!_sameIds(taxes, _origTaxes)) return true;
    if (isActive != _origIsActive) return true;
    if (saleOk != _origSaleOk) return true;
    if (purchaseOk != _origPurchaseOk) return true;
    if (imageBase64 != _origImageBase64) return true;
    if (trackInventory != _origTrackInventory) return true;
    return false;
  }

  bool get requiredFieldsFilled =>
      name.trim().isNotEmpty && categId != null && uomId != null;

  /// A new product only needs its required fields; an existing one also
  /// needs something to have changed.
  bool get canSave =>
      !saving &&
      recordLoaded &&
      requiredFieldsFilled &&
      (isCreateMode || hasUnsavedChanges);

  /// Fields read for the form. Anything the server lacks is dropped before
  /// the read (see the class doc).
  static const List<String> readFields = [
    'name',
    'default_code',
    'barcode',
    'description_sale',
    'list_price',
    'standard_price',
    'weight',
    'volume',
    'sale_delay',
    'categ_id',
    'uom_id',
    'currency_id',
    'taxes_id',
    'product_tmpl_id',
    'active',
    'sale_ok',
    'purchase_ok',
    'image_1920',
  ];

  /// What every database with the `product` app has, used when `fields_get`
  /// itself could not be fetched.
  static const Set<String> _coreProductFields = {
    'name',
    'default_code',
    'barcode',
    'description_sale',
    'list_price',
    'standard_price',
    'weight',
    'volume',
    'categ_id',
    'uom_id',
    'currency_id',
    'product_tmpl_id',
    'active',
    'sale_ok',
    'purchase_ok',
    'image_1920',
    'type',
  };

  bool _hasField(String field) {
    final info = _fieldsInfo;
    if (info == null) return _coreProductFields.contains(field);
    return info.containsKey(field);
  }

  /// Whether [field] can be sent in a create/write. Computed fields without
  /// an inverse (`currency_id`) come back `readonly` and are skipped.
  bool _isWritable(String field) {
    final info = _fieldsInfo;
    if (info == null) {
      return _coreProductFields.contains(field) && field != 'currency_id';
    }
    final meta = info[field];
    if (meta == null) return false;
    return !(meta is Map && meta['readonly'] == true);
  }

  Map<String, dynamic> _writable(Map<String, dynamic> vals) => {
    for (final entry in vals.entries)
      if (_isWritable(entry.key)) entry.key: entry.value,
  };

  Future<void> _fetchFieldsInfo(String model) async {
    try {
      final res = await _callKw({
        'model': model,
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': ['type', 'readonly', 'required', 'selection'],
        },
      });
      _fieldsInfo = res is Map ? Map<String, dynamic>.from(res) : null;
    } catch (_) {
      _fieldsInfo = null;
    }
  }

  /// Loads `product.product` [productId] into the form.
  Future<void> load(int productId) async {
    this.productId = productId;
    loading = true;
    error = null;
    recordLoaded = false;
    notifyListeners();

    await _fetchFieldsInfo('product.product');

    final fields = readFields.where(_hasField).toList();

    Future<void> readProduct() async {
      try {
        final res = await _callKw({
          'model': 'product.product',
          'method': 'read',
          'args': [
            [productId],
          ],
          'kwargs': {'fields': fields},
        });

        if (res is List && res.isNotEmpty) {
          _parseProductData(Map<String, dynamic>.from(res.first as Map));
          recordLoaded = true;
        } else {
          error =
              'This product no longer exists or you do not have access to it.';
        }
      } catch (e) {
        error = _getUserFriendlyErrorMessage(e, action: 'load');
      }
    }

    await Future.wait([readProduct(), _loadDropdownOptions()]);
    await _ensureSelectedOptions();

    loading = false;
    notifyListeners();
  }

  /// Sets the form up for a new product, prefilled with the server's own
  /// defaults (unit of measure, sales taxes, flags).
  Future<void> initCreate() async {
    productId = null;
    templateId = null;
    loading = true;
    error = null;
    recordLoaded = false;
    notifyListeners();

    await _fetchFieldsInfo('product.template');

    Future<void> applyDefaults() async {
      final wanted = [
        'categ_id',
        'uom_id',
        'currency_id',
        'taxes_id',
        'sale_ok',
        'purchase_ok',
        'list_price',
        'active',
      ].where(_hasField).toList();
      try {
        final res = await _callKw({
          'model': 'product.template',
          'method': 'default_get',
          'args': [wanted],
          'kwargs': {},
        });
        if (res is Map) _parseDefaults(Map<String, dynamic>.from(res));
      } catch (_) {
        // No defaults: the user fills the required fields in.
      }
    }

    await Future.wait([applyDefaults(), _loadDropdownOptions()]);
    await _ensureSelectedOptions();

    _snapshotOriginals();
    recordLoaded = true;
    loading = false;
    notifyListeners();
  }

  /// Odoo sends `false` for an empty text field; `toString()` on that
  /// would show the word "false" in the form.
  static String _text(dynamic v) =>
      (v == null || v == false) ? '' : v.toString();

  void _parseProductData(Map<String, dynamic> m) {
    name = _text(m['name']).trim();
    sku = _text(m['default_code']).trim();
    barcode = _text(m['barcode']);
    description = _text(m['description_sale']);
    listPrice = _toDouble(m['list_price']);
    standardPrice = _toDouble(m['standard_price']);
    weight = _toDouble(m['weight']);
    volume = _toDouble(m['volume']);
    leadTime = _toDouble(m['sale_delay']);

    categId = _m2oId(m['categ_id']);
    uomId = _m2oId(m['uom_id']);
    currencyId = _m2oId(m['currency_id']);
    _categLabel = _m2oLabel(m['categ_id']);
    _uomLabel = _m2oLabel(m['uom_id']);
    _currencyLabel = _m2oLabel(m['currency_id']);
    taxes = _many2manyIds(m['taxes_id']);
    templateId = _m2oId(m['product_tmpl_id']);

    isActive = (m['active'] as bool?) ?? true;
    saleOk = (m['sale_ok'] as bool?) ?? true;
    purchaseOk = (m['purchase_ok'] as bool?) ?? true;

    final img = odooBinaryToBase64(m['image_1920']);
    imageBase64 = img.isNotEmpty ? img : null;

    _snapshotOriginals();
  }

  void _parseDefaults(Map<String, dynamic> d) {
    if (d.containsKey('categ_id')) categId = _m2oId(d['categ_id']);
    if (d.containsKey('uom_id')) uomId = _m2oId(d['uom_id']);
    if (d.containsKey('currency_id')) currencyId = _m2oId(d['currency_id']);
    if (d.containsKey('taxes_id')) taxes = _commandIds(d['taxes_id']);
    if (d['sale_ok'] is bool) saleOk = d['sale_ok'] as bool;
    if (d['purchase_ok'] is bool) purchaseOk = d['purchase_ok'] as bool;
    if (d['active'] is bool) isActive = d['active'] as bool;
    listPrice = _toDouble(d['list_price']) ?? listPrice;
  }

  void _snapshotOriginals() {
    _origName = name;
    _origSku = sku;
    _origBarcode = barcode;
    _origDescription = description;
    _origListPrice = listPrice;
    _origStandardPrice = standardPrice;
    _origWeight = weight;
    _origVolume = volume;
    _origLeadTime = leadTime;
    _origCategId = categId;
    _origUomId = uomId;
    _origCurrencyId = currencyId;
    _origTaxes = List<int>.from(taxes);
    _origIsActive = isActive;
    _origSaleOk = saleOk;
    _origPurchaseOk = purchaseOk;
    _origImageBase64 = imageBase64;
    _origTrackInventory = trackInventory;
  }

  Future<void> _loadDropdownOptions() async {
    await Future.wait([
      _fetchCategories(),
      _fetchUOMs(),
      _fetchCurrencies(),
      if (hasTaxesField) _fetchTaxes(),
    ]);
  }

  /// Makes sure the record's own category, unit, currency and taxes are
  /// among the dropdown options, so they show by name rather than as a bare
  /// id when they fall outside the (capped) option lists.
  Future<void> _ensureSelectedOptions() async {
    void ensure(List<Map<String, String>> options, int? id, String? label) {
      if (id == null) return;
      final value = id.toString();
      if (options.any((o) => o['value'] == value)) return;
      options.insert(0, {'value': value, 'label': label ?? value});
    }

    ensure(categoryOptions, categId, _categLabel);
    ensure(uomOptions, uomId, _uomLabel);
    ensure(currencyOptions, currencyId, _currencyLabel);

    final missingTaxes = [
      for (final id in taxes)
        if (!taxOptions.any((o) => o['value'] == id.toString())) id,
    ];
    if (missingTaxes.isEmpty || !hasTaxesField) return;
    try {
      final res = await _callKw({
        'model': 'account.tax',
        'method': 'read',
        'args': [missingTaxes],
        'kwargs': {
          'fields': ['id', 'name', 'amount'],
        },
      });
      if (res is List) {
        taxOptions = [...taxOptions, ...res.map(_taxOption)];
      }
    } catch (_) {
      // Shown by id; still kept on save.
    }
  }

  static Map<String, String> _taxOption(dynamic r) => {
    'value': r['id'].toString(),
    'label': '${r['name']} (${r['amount'] ?? 0}%)',
  };

  Future<void> _fetchCategories() async {
    try {
      final res = await _callKw({
        'model': 'product.category',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          // The full path, so sub-categories that share a name stay apart.
          'fields': ['id', 'name', 'complete_name'],
          'order': 'name ASC',
          'limit': 200,
        },
      });

      if (res is List) {
        categoryOptions =
            res.map((r) {
              final complete = r['complete_name'];
              return {
                'value': r['id'].toString(),
                'label': (complete is String && complete.isNotEmpty)
                    ? complete
                    : r['name'].toString(),
              };
            }).toList()..sort(
              (a, b) => a['label']!.toLowerCase().compareTo(
                b['label']!.toLowerCase(),
              ),
            );
      }
    } catch (_) {
      categoryOptions = [];
    }
  }

  Future<void> _fetchUOMs() async {
    try {
      final res = await _callKw({
        'model': 'uom.uom',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name ASC',
          'limit': 200,
        },
      });

      if (res is List) {
        uomOptions = res
            .map(
              (r) => {
                'value': r['id'].toString(),
                'label': r['name'].toString(),
              },
            )
            .toList();
      }
    } catch (_) {
      uomOptions = [];
    }
  }

  Future<void> _fetchCurrencies() async {
    try {
      final res = await _callKw({
        'model': 'res.currency',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'symbol'],
          'order': 'name ASC',
          'limit': 50,
        },
      });

      if (res is List) {
        currencyOptions = res
            .map(
              (r) => {
                'value': r['id'].toString(),
                'label': '${r['name']} (${r['symbol']})',
              },
            )
            .toList();
      }
    } catch (_) {
      currencyOptions = [];
    }
  }

  Future<void> _fetchTaxes() async {
    try {
      final res = await _callKw({
        'model': 'account.tax',
        'method': 'search_read',
        'args': [
          [
            ['type_tax_use', '=', 'sale'],
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'amount'],
          'order': 'name ASC',
          'limit': 100,
        },
      });

      if (res is List) {
        taxOptions = res.map(_taxOption).toList();
      }
    } catch (_) {
      taxOptions = [];
    }
  }

  void setImage(String? b64) {
    imageBase64 = b64;
    notifyListeners();
  }

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setSku(String v) {
    sku = v;
    notifyListeners();
  }

  void setBarcode(String v) {
    barcode = v;
    notifyListeners();
  }

  void setDescription(String v) {
    description = v;
    notifyListeners();
  }

  void setListPrice(double? v) {
    listPrice = v;
    notifyListeners();
  }

  void setStandardPrice(double? v) {
    standardPrice = v;
    notifyListeners();
  }

  void setWeight(double? v) {
    weight = v;
    notifyListeners();
  }

  void setVolume(double? v) {
    volume = v;
    notifyListeners();
  }

  void setLeadTime(double? v) {
    leadTime = v;
    notifyListeners();
  }

  void setCategory(int? id) {
    categId = id;
    notifyListeners();
  }

  void setUom(int? id) {
    uomId = id;
    notifyListeners();
  }

  void setCurrency(int? id) {
    currencyId = id;
    notifyListeners();
  }

  void setTaxes(List<int> ids) {
    taxes = ids;
    notifyListeners();
  }

  void setSaleOk(bool v) {
    saleOk = v;
    notifyListeners();
  }

  void setPurchaseOk(bool v) {
    purchaseOk = v;
    notifyListeners();
  }

  void setIsActive(bool v) {
    isActive = v;
    notifyListeners();
  }

  void setTrackInventory(bool v) {
    trackInventory = v;
    notifyListeners();
  }

  /// Creates the product (create mode) or writes the changed fields back to
  /// the product that was loaded (edit mode).
  Future<bool> save() async {
    saving = true;
    error = null;
    notifyListeners();

    try {
      if (isCreateMode) {
        await _create();
      } else {
        await _write();
      }
      _snapshotOriginals();
      saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = _getUserFriendlyErrorMessage(
        e,
        action: isCreateMode ? 'create' : 'save',
      );
      saving = false;
      notifyListeners();
      return false;
    }
  }

  static dynamic _textOrFalse(String v) => v.trim().isEmpty ? false : v.trim();

  /// Writes only what changed, each field on the record that owns it:
  /// variant-level fields (internal reference, barcode, cost, weight,
  /// volume, image) on the `product.product`, the rest on its template.
  /// Unchanged values are never re-sent, so opening and saving a product
  /// cannot round its prices or trip Odoo's checks on fields like the unit
  /// of measure.
  Future<void> _write() async {
    final variantVals = <String, dynamic>{};
    final templateVals = <String, dynamic>{};

    if (sku.trim() != _origSku) variantVals['default_code'] = _textOrFalse(sku);
    if (barcode.trim() != _origBarcode.trim()) {
      variantVals['barcode'] = _textOrFalse(barcode);
    }
    if (!_doubleEquals(standardPrice, _origStandardPrice)) {
      variantVals['standard_price'] = standardPrice ?? 0.0;
    }
    if (!_doubleEquals(weight, _origWeight)) {
      variantVals['weight'] = weight ?? 0.0;
    }
    if (!_doubleEquals(volume, _origVolume)) {
      variantVals['volume'] = volume ?? 0.0;
    }
    if (imageBase64 != _origImageBase64) {
      variantVals['image_1920'] =
          (imageBase64 != null && imageBase64!.isNotEmpty)
          ? imageBase64
          : false;
    }
    if (isActive != _origIsActive) {
      variantVals['active'] = isActive;
      templateVals['active'] = isActive;
    }

    if (name.trim() != _origName.trim() && name.trim().isNotEmpty) {
      templateVals['name'] = name.trim();
    }
    if (description != _origDescription) {
      templateVals['description_sale'] = description.isNotEmpty
          ? description
          : false;
    }
    if (!_doubleEquals(listPrice, _origListPrice)) {
      templateVals['list_price'] = listPrice ?? 0.0;
    }
    if (!_doubleEquals(leadTime, _origLeadTime)) {
      templateVals['sale_delay'] = (leadTime ?? 0).round();
    }
    if (categId != _origCategId) templateVals['categ_id'] = categId ?? false;
    if (uomId != _origUomId && uomId != null) templateVals['uom_id'] = uomId;
    if (!_sameIds(taxes, _origTaxes)) {
      templateVals['taxes_id'] = [
        [6, 0, taxes],
      ];
    }
    if (saleOk != _origSaleOk) templateVals['sale_ok'] = saleOk;
    if (purchaseOk != _origPurchaseOk) {
      templateVals['purchase_ok'] = purchaseOk;
    }

    final variantWrite = _writable(variantVals);
    final templateWrite = _writable(templateVals);

    if (variantWrite.isNotEmpty) {
      await _callKw({
        'model': 'product.product',
        'method': 'write',
        'args': [
          [productId],
          variantWrite,
        ],
        'kwargs': {},
      });
    }

    if (templateWrite.isNotEmpty) {
      final tmplId = templateId;
      if (tmplId != null) {
        await _callKw({
          'model': 'product.template',
          'method': 'write',
          'args': [
            [tmplId],
            templateWrite,
          ],
          'kwargs': {},
        });
      } else {
        // No template id came back: the variant delegates template fields
        // to its template itself.
        await _callKw({
          'model': 'product.product',
          'method': 'write',
          'args': [
            [productId],
            templateWrite,
          ],
          'kwargs': {},
        });
      }
    }
  }

  Future<void> _create() async {
    final vals = <String, dynamic>{
      'name': name.trim(),
      if (categId != null) 'categ_id': categId,
      if (uomId != null) 'uom_id': uomId,
      if (sku.trim().isNotEmpty) 'default_code': sku.trim(),
      if (barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
      if (listPrice != null) 'list_price': listPrice,
      if (standardPrice != null) 'standard_price': standardPrice,
      if (weight != null) 'weight': weight,
      if (volume != null) 'volume': volume,
      if (description.trim().isNotEmpty) 'description_sale': description,
      if (hasTaxesField)
        'taxes_id': [
          [6, 0, taxes],
        ],
      'sale_ok': saleOk,
      'purchase_ok': purchaseOk,
      'active': isActive,
      if (imageBase64 != null && imageBase64!.isNotEmpty)
        'image_1920': imageBase64,
    };

    if (_hasField('is_storable')) {
      // Odoo 18+: a stock-tracked product is a "Goods" product flagged
      // storable.
      vals['is_storable'] = trackInventory;
    } else if (_typeSelection.contains('product')) {
      vals['type'] = trackInventory ? 'product' : 'consu';
    }

    final res = await _callKw({
      'model': 'product.template',
      'method': 'create',
      'args': [_writable(vals)],
      'kwargs': {},
    });

    if (res is int) {
      createdTemplateId = res;
    } else if (res is List && res.isNotEmpty && res.first is int) {
      createdTemplateId = res.first as int;
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error, {String action = 'save'}) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('accesserror') ||
        errorString.contains('access denied')) {
      switch (action) {
        case 'create':
          return 'You don\'t have permission to create products.';
        case 'load':
          return 'You don\'t have permission to view this product.';
        default:
          return 'You don\'t have permission to edit this product.';
      }
    }
    if (errorString.contains('missingerror') ||
        errorString.contains('does not exist')) {
      return 'This product no longer exists or has been deleted.';
    }
    if (errorString.contains('validationerror')) {
      if (errorString.contains('barcode')) {
        return 'Invalid barcode or barcode already exists.';
      }
      if (errorString.contains('name')) {
        return 'Product name is required.';
      }
      return 'Please check your input data.';
    }
    if (errorString.contains('duplicate') || errorString.contains('unique')) {
      return 'A product with this barcode already exists.';
    }
    if (errorString.contains('socketexception') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (errorString.contains('session') ||
        errorString.contains('authentication')) {
      return 'Session expired. Please log in again.';
    }

    switch (action) {
      case 'load':
        return 'Failed to load product: ${error.toString()}';
      case 'create':
        return 'Failed to create product: ${error.toString()}';
      default:
        return 'Failed to save: ${error.toString()}';
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null || v == false) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool _doubleEquals(double? a, double? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return (a - b).abs() < 1e-9;
  }

  /// Many2many ids compared as sets: the order the server returns them in
  /// is not a change.
  bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }

  int? _m2oId(dynamic v) {
    if (v == null || v == false) return null;
    if (v is List && v.isNotEmpty) return v.first as int;
    if (v is int) return v;
    if (v is Map && v['id'] is int) return v['id'] as int;
    return null;
  }

  String? _m2oLabel(dynamic v) {
    if (v is List && v.length > 1) return v[1]?.toString();
    if (v is Map) return (v['display_name'] ?? v['name'])?.toString();
    return null;
  }

  List<int> _many2manyIds(dynamic v) {
    if (v is List) {
      return v.whereType<int>().toList();
    }
    return [];
  }

  /// Ids out of a `default_get` x2many value: plain ids, or `(6, 0, ids)` /
  /// `(4, id)` commands.
  List<int> _commandIds(dynamic v) {
    if (v is! List) return [];
    final ids = <int>[];
    for (final item in v) {
      if (item is int) {
        ids.add(item);
      } else if (item is List && item.isNotEmpty) {
        if (item.first == 6 && item.length > 2 && item[2] is List) {
          ids.addAll((item[2] as List).whereType<int>());
        } else if (item.first == 4 && item.length > 1 && item[1] is int) {
          ids.add(item[1] as int);
        }
      }
    }
    return ids;
  }
}
