import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';

class InventoryProductEditViewModel extends ChangeNotifier {

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

  int? templateId;

  List<Map<String, String>> categoryOptions = [];
  List<Map<String, String>> taxOptions = [];
  List<Map<String, String>> uomOptions = [];
  List<Map<String, String>> currencyOptions = [];

  bool loading = true;
  bool saving = false;
  String? error;

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
    if (!_listEqualsInt(taxes, _origTaxes)) return true;
    if (isActive != _origIsActive) return true;
    if (saleOk != _origSaleOk) return true;
    if (purchaseOk != _origPurchaseOk) return true;
    if (imageBase64 != _origImageBase64) return true;
    return false;
  }

  Future<void> load(int productId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'read',
        'args': [
          [productId],
        ],
        'kwargs': {
          'fields': [
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
          ],
        },
      });

      if (res is List && res.isNotEmpty) {
        final m = Map<String, dynamic>.from(res.first as Map);
        _parseProductData(m);
      }

      await _loadDropdownOptions();
    } catch (e) {
      error = _getUserFriendlyErrorMessage(e);
    }

    loading = false;
    notifyListeners();
  }

  void _parseProductData(Map<String, dynamic> m) {
    name = (m['name']?.toString() ?? '').trim();
    sku = (m['default_code']?.toString() ?? '').trim();

    final bc = m['barcode'];
    barcode = (bc == null || bc == false) ? '' : bc.toString();

    description = (m['description_sale']?.toString() ?? '');
    listPrice = _toDouble(m['list_price']);
    standardPrice = _toDouble(m['standard_price']);
    weight = _toDouble(m['weight']);
    volume = _toDouble(m['volume']);
    leadTime = _toDouble(m['sale_delay']);

    categId = _m2oId(m['categ_id']);
    uomId = _m2oId(m['uom_id']);
    currencyId = _m2oId(m['currency_id']);
    taxes = _many2manyIds(m['taxes_id']);
    templateId = _m2oId(m['product_tmpl_id']);

    isActive = (m['active'] as bool?) ?? true;
    saleOk = (m['sale_ok'] as bool?) ?? true;
    purchaseOk = (m['purchase_ok'] as bool?) ?? true;

    final img = m['image_1920'];
    if (img != null && img != false && img.toString().isNotEmpty) {
      imageBase64 = img.toString();
    }

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
  }

  Future<void> _loadDropdownOptions() async {
    await Future.wait([
      _fetchCategories(),
      _fetchUOMs(),
      _fetchCurrencies(),
      _fetchTaxes(),
    ]);
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'product.category',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name ASC',
          'limit': 100,
        },
      });

      if (res is List) {
        categoryOptions = res
            .map(
              (r) => {
                'value': r['id'].toString(),
                'label': r['name'].toString(),
              },
            )
            .toList();
      }
    } catch (_) {
      categoryOptions = [];
    }
  }

  Future<void> _fetchUOMs() async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
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
          'limit': 100,
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
      final res = await OdooSessionManager.callKwWithCompany({
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
      final res = await OdooSessionManager.callKwWithCompany({
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
        taxOptions = res
            .map(
              (r) => {
                'value': r['id'].toString(),
                'label': '${r['name']} (${r['amount'] ?? 0}%)',
              },
            )
            .toList();
      }
    } catch (_) {
      taxOptions = [];
    }
  }

  void setImage(String? b64) {
    imageBase64 = b64;
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

  Future<bool> save(int productId) async {
    saving = true;
    error = null;
    notifyListeners();

    try {

      final productData = <String, dynamic>{};

      if (sku.trim().isNotEmpty) {
        productData['default_code'] = sku.trim();
      }

      if (barcode.trim().isNotEmpty) {
        productData['barcode'] = barcode.trim();
      } else {
        productData['barcode'] = false;
      }

      if (weight != null) productData['weight'] = weight;
      if (volume != null) productData['volume'] = volume;
      if (leadTime != null) productData['sale_delay'] = leadTime;

      if (imageBase64 != null && imageBase64!.isNotEmpty) {
        productData['image_1920'] = imageBase64;
      }

      productData['active'] = isActive;

      await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'write',
        'args': [
          [productId],
          productData,
        ],
        'kwargs': {},
      });

      if (templateId != null) {
        final templateData = <String, dynamic>{};

        if (name.trim().isNotEmpty) {
          templateData['name'] = name.trim();
        }

        if (description.isNotEmpty) {
          templateData['description_sale'] = description;
        }

        if (listPrice != null) templateData['list_price'] = listPrice;
        if (standardPrice != null)
          templateData['standard_price'] = standardPrice;

        if (categId != null) templateData['categ_id'] = categId;
        if (uomId != null) templateData['uom_id'] = uomId;

        if (currencyId != null) templateData['currency_id'] = currencyId;

        if (taxes.isNotEmpty) {
          templateData['taxes_id'] = [
            [6, 0, taxes],
          ];
        } else {
          templateData['taxes_id'] = [
            [6, 0, []],
          ];
        }

        templateData['sale_ok'] = saleOk;
        templateData['purchase_ok'] = purchaseOk;
        templateData['active'] = isActive;

        await OdooSessionManager.callKwWithCompany({
          'model': 'product.template',
          'method': 'write',
          'args': [
            [templateId],
            templateData,
          ],
          'kwargs': {},
        });
      }

      saving = false;
      notifyListeners();

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
      return true;
    } catch (e) {
      error = _getUserFriendlyErrorMessage(e);
      saving = false;
      notifyListeners();
      return false;
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('accesserror') ||
        errorString.contains('access denied')) {
      return 'You don\'t have permission to edit this product.';
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

    return 'Failed to save: ${error.toString()}';
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

  bool _listEqualsInt(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int? _m2oId(dynamic v) {
    if (v == null || v == false) return null;
    if (v is List && v.isNotEmpty) return v.first as int;
    if (v is int) return v;
    return null;
  }

  List<int> _many2manyIds(dynamic v) {
    if (v is List) {
      return v.whereType<int>().toList();
    }
    return [];
  }
}
