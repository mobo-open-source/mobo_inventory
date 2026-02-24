import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';
import '../models/recent_activity.dart';
import '../models/negative_quant.dart';
import '../models/today_activity.dart';
import '../models/replenishment_need.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/user_cache_service.dart';
import '../../../core/utils/base64_utils.dart';

/// Provider for managing the dashboard state and fetching analytics data.
class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider({DashboardService? service})
    : _service = service ?? DashboardService();

  DashboardStats _stats = DashboardStats.empty();
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedData = false;
  List<RecentActivity> _recent = const [];
  bool _isLoadingRecent = false;
  List<NegativeQuant> _negativeQuants = const [];
  bool _isLoadingNegative = false;
  List<TodayActivity> _todayActivities = const [];
  bool _isLoadingToday = false;
  int _incomingToday = 0;
  int _outgoingToday = 0;
  bool _isLoadingOpsToday = false;
  List<ReplenishmentNeed> _replenishmentNeeds = const [];
  bool _isLoadingReplenishment = false;
  String? _userName;
  Uint8List? _userAvatarBytes;
  String? _userAvatarBase64;
  bool _isLoadingUser = false;

  DashboardStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoadedData => _hasLoadedData;
  List<RecentActivity> get recentActivities => _recent;
  bool get isLoadingRecent => _isLoadingRecent;
  List<NegativeQuant> get negativeQuants => _negativeQuants;
  bool get isLoadingNegative => _isLoadingNegative;
  List<TodayActivity> get todayActivities => _todayActivities;
  bool get isLoadingToday => _isLoadingToday;
  int get incomingToday => _incomingToday;
  int get outgoingToday => _outgoingToday;
  bool get isLoadingOpsToday => _isLoadingOpsToday;
  List<ReplenishmentNeed> get replenishmentNeeds => _replenishmentNeeds;
  bool get isLoadingReplenishment => _isLoadingReplenishment;
  String? get userName => _userName;
  Uint8List? get userAvatarBytes => _userAvatarBytes;
  String? get userAvatarBase64 => _userAvatarBase64;
  bool get isLoadingUser => _isLoadingUser;

  /// Fetches high-level dashboard statistics (warehouses, locations, orders, etc.).
  Future<void> fetchStats({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _service.fetchDashboardStats();
      _error = null;
      _hasLoadedData = true;
    } catch (e) {
      _error = OdooErrorMapper.toUserMessage(e);
      if (e is NoInternetException || e is ServerUnreachableException) {
        _stats = DashboardStats.empty();
        _hasLoadedData = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayOperationsCounts() async {
    if (_isLoadingOpsToday) return;
    _isLoadingOpsToday = true;
    notifyListeners();
    try {
      final results = await Future.wait<int>([
        _service.fetchIncomingTodayCount(),
        _service.fetchOutgoingTodayCount(),
      ]);
      _incomingToday = results[0];
      _outgoingToday = results[1];
    } catch (e) {
      _incomingToday = 0;
      _outgoingToday = 0;
    } finally {
      _isLoadingOpsToday = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentActivities({int limit = 10}) async {
    if (_isLoadingRecent) return;
    _isLoadingRecent = true;
    notifyListeners();
    try {
      _recent = await _service.fetchRecentActivities(limit: limit);
    } catch (e) {
      _recent = const [];
    } finally {
      _isLoadingRecent = false;
      notifyListeners();
    }
  }

  Future<void> fetchNegativeQuants({int limit = 4}) async {
    if (_isLoadingNegative) return;
    _isLoadingNegative = true;
    notifyListeners();
    try {
      _negativeQuants = await _service.fetchNegativeQuants(limit: limit);
    } catch (e) {
      _negativeQuants = const [];
    } finally {
      _isLoadingNegative = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayActivities({int limit = 4}) async {
    if (_isLoadingToday) return;
    _isLoadingToday = true;
    notifyListeners();
    try {
      _todayActivities = await _service.fetchTodayActivities(limit: limit);
    } catch (e) {
      _todayActivities = const [];
    } finally {
      _isLoadingToday = false;
      notifyListeners();
    }
  }

  Future<void> fetchReplenishmentNeeds({int limit = 4}) async {
    if (_isLoadingReplenishment) return;
    _isLoadingReplenishment = true;
    notifyListeners();
    try {
      _replenishmentNeeds = await _service.fetchReplenishmentNeeds(
        limit: limit,
      );
    } catch (e) {
      _replenishmentNeeds = const [];
    } finally {
      _isLoadingReplenishment = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserInfo() async {
    if (_isLoadingUser) return;
    _isLoadingUser = true;
    notifyListeners();

    try {
      final cachedName = await UserCacheService.instance.getCachedUserName();
      final cachedAvatar = await UserCacheService.instance
          .getCachedUserAvatar();
      if (cachedName != null) _userName = cachedName;
      if (cachedAvatar != null) _userAvatarBytes = cachedAvatar;
      notifyListeners();

      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) return;

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          ['name', 'image_1920'],
        ],
        'kwargs': {},
      });

      if (res is List && res.isNotEmpty) {
        final userData = res.first;
        final name = userData['name']?.toString();
        final img = userData['image_1920'];

        if (name != null) _userName = name;

        if (img != null && img != false) {
          if (img is String && img.isNotEmpty && img != 'false') {
            final bytes = await compute(decodeBase64ToBytes, img);
            if (bytes.isNotEmpty) {
              _userAvatarBytes = bytes;
            }
          }
          if (img is String && img.isNotEmpty && img != 'false') {
            _userAvatarBase64 = img;
          }
        }

        if (_userName != null) {
          await UserCacheService.instance.saveUserInfo(
            userId: session.userId,
            userName: _userName!,
            avatarBase64: img is String && img.isNotEmpty && img != 'false'
                ? img
                : null,
          );
        }
      }
    } catch (e) {
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  /// Refreshes all dashboard data components.
  Future<void> refreshAll() async {
    await Future.wait([
      fetchStats(forceRefresh: true),
      fetchTodayOperationsCounts(),
      fetchRecentActivities(limit: 4),
      fetchNegativeQuants(limit: 4),
      fetchTodayActivities(limit: 4),
      fetchReplenishmentNeeds(limit: 4),
      fetchUserInfo(),
    ]);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetState() {
    _stats = DashboardStats.empty();
    _isLoading = false;
    _error = null;
    _hasLoadedData = false;
    _recent = const [];
    _isLoadingRecent = false;
    _negativeQuants = const [];
    _isLoadingNegative = false;
    _todayActivities = const [];
    _isLoadingToday = false;
    _incomingToday = 0;
    _outgoingToday = 0;
    _isLoadingOpsToday = false;
    _replenishmentNeeds = const [];
    _isLoadingReplenishment = false;
    _userName = null;
    _userAvatarBytes = null;
    _userAvatarBase64 = null;
    _isLoadingUser = false;
    notifyListeners();
  }
}
