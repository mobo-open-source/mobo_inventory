import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/services/odoo_session_manager.dart';

class LastOpenedItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String route;
  final Map<String, dynamic>? data;
  final DateTime lastAccessed;
  final String iconKey;

  LastOpenedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
    this.data,
    required this.lastAccessed,
    required this.iconKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'route': route,
      'data': data,
      'lastAccessed': lastAccessed.toIso8601String(),
      'iconKey': iconKey,
    };
  }

  /// Whether the signed-in user may open this item: its record must be
  /// readable, and a tab it opens must be shown — the shell sends the user
  /// straight back to the Dashboard from a hidden one. Fails open like
  /// [AccessRightsService.can].
  bool canOpen(AccessRightsService access) {
    switch (route) {
      case AppRoutes.inventoryProductDetail:
        return access.can('product.product', 'read');
      case AppRoutes.transferDetail:
        return access.can('stock.picking', 'read');
      case AppRoutes.replenishment:
        return access.isBranchVisible(AccessRightsService.replenishmentBranch);
    }
    return true;
  }

  static IconData iconFromKey(String key) {
    switch (key) {
      case 'inventory_2_outlined':
        return HugeIcons.strokeRoundedPackageOpen;
      case 'transfer':
        return HugeIcons.strokeRoundedDeliveryTruck01;
      case 'replenishment':
        return HugeIcons.strokeRoundedReload;
      default:
        return HugeIcons.strokeRoundedFile02;
    }
  }

  static LastOpenedItem fromJson(Map<String, dynamic> json) {
    return LastOpenedItem(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      subtitle: json['subtitle'],
      route: json['route'],
      data: json['data'],
      lastAccessed: DateTime.parse(json['lastAccessed']),
      iconKey: json['iconKey'] ?? 'page',
    );
  }
}

class LastOpenedProvider extends ChangeNotifier {
  /// The pre-scoping key, shared by every account. Its items cannot be
  /// attributed to any one account, so it is dropped rather than migrated.
  static const String _legacyStorageKey = 'last_opened_items_inv';
  static const int _maxItems = 10;

  List<LastOpenedItem> _items = [];

  List<LastOpenedItem> get items => List.unmodifiable(_items);

  LastOpenedItem? get lastOpened => _items.isNotEmpty ? _items.first : null;

  LastOpenedProvider() {
    _loadItems();
  }

  /// Recent items are stored per account (`serverUrl|database|userId`).
  /// One shared list showed account A's records on account B's dashboard,
  /// and tapping one opened that record id on the wrong database.
  Future<String?> _storageKey() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return null;
    return '$_legacyStorageKey|${session.serverUrl}|${session.database}|'
        '${session.userId}';
  }

  /// Swaps in the recent items of the account now signed in. Called on every
  /// account change.
  Future<void> reloadForCurrentAccount() async {
    _items = [];
    notifyListeners();
    await _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyStorageKey);

      final key = await _storageKey();
      final jsonString = key == null ? null : prefs.getString(key);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _items = jsonList.map((json) => LastOpenedItem.fromJson(json)).toList();

        _items.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
      } else {
        _items = [];
      }
      notifyListeners();
    } catch (e) {
      _items = [];
    }
  }

  Future<void> _saveItems() async {
    try {
      final key = await _storageKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
    } catch (e) {}
  }

  Future<void> addItem(LastOpenedItem item) async {
    _items.removeWhere((existingItem) => existingItem.id == item.id);

    _items.insert(0, item);

    if (_items.length > _maxItems) {
      _items = _items.take(_maxItems).toList();
    }

    await _saveItems();
    notifyListeners();
  }

  Future<void> trackInventoryProductAccess({
    required String productId,
    required String productName,
    String? category,
    Map<String, dynamic>? productData,
  }) async {
    final item = LastOpenedItem(
      id: 'product_$productId',
      type: 'product',
      title: productName,
      subtitle: category != null ? 'Product in $category' : 'Product',
      route: AppRoutes.inventoryProductDetail,
      data: productData,
      lastAccessed: DateTime.now(),
      iconKey: 'inventory_2_outlined',
    );

    await addItem(item);
  }

  Future<void> trackTransferAccess({
    required String transferId,
    required String transferName,
    required String state,
    Map<String, dynamic>? transferData,
  }) async {
    final item = LastOpenedItem(
      id: 'transfer_$transferId',
      type: 'transfer',
      title: transferName,
      subtitle: 'Status: $state',
      route: AppRoutes.transferDetail,
      data: transferData,
      lastAccessed: DateTime.now(),
      iconKey: 'transfer',
    );

    await addItem(item);
  }

  Future<void> trackReplenishmentAccess({
    required String replenishmentId,
    required String productName,
    required String locationName,
    Map<String, dynamic>? data,
  }) async {
    final item = LastOpenedItem(
      id: 'replenishment_$replenishmentId',
      type: 'replenishment',
      title: productName,
      subtitle: locationName,
      route: AppRoutes.replenishment,
      data: data,
      lastAccessed: DateTime.now(),
      iconKey: 'replenishment',
    );

    await addItem(item);
  }

  Future<void> clearItems() async {
    _items.clear();
    await _saveItems();
    notifyListeners();
  }

  Future<void> removeItem(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    await _saveItems();
    notifyListeners();
  }

  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}
