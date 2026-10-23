import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';
import '../models/recent_activity.dart';
import '../models/negative_quant.dart';
import '../models/today_activity.dart';
import '../models/replenishment_need.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/services/connectivity_service.dart';

/// The dashboard's independently loaded parts.
enum _Section { stats, opsToday, recent, negative, today, replenishment }

/// Provider for managing the dashboard state and fetching analytics data.
class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider({DashboardService? service})
    : _service = service ?? DashboardService();

  DashboardStats _stats = DashboardStats.empty();
  String? _error;
  bool _hasLoadedData = false;
  List<RecentActivity> _recent = const [];
  List<NegativeQuant> _negativeQuants = const [];
  List<TodayActivity> _todayActivities = const [];
  int _incomingToday = 0;
  int _outgoingToday = 0;
  List<ReplenishmentNeed> _replenishmentNeeds = const [];

  /// Sections with a load in flight.
  final Set<_Section> _loading = {};

  /// Number of the latest load started per section. Every RPC runs in the
  /// company scope of the moment it is sent, so a load that started before
  /// the scope changed (right after sign-in, the company list settles a
  /// moment after the dashboard's first load) answers for the old scope. A
  /// forced reload therefore supersedes the load in flight instead of
  /// waiting on it, and a superseded load's result is dropped.
  final Map<_Section, int> _latestLoad = {};

  DashboardStats get stats => _stats;
  bool get isLoading => _loading.contains(_Section.stats);
  String? get error => _error;
  bool get hasLoadedData => _hasLoadedData;
  List<RecentActivity> get recentActivities => _recent;
  bool get isLoadingRecent => _loading.contains(_Section.recent);
  List<NegativeQuant> get negativeQuants => _negativeQuants;
  bool get isLoadingNegative => _loading.contains(_Section.negative);
  List<TodayActivity> get todayActivities => _todayActivities;
  bool get isLoadingToday => _loading.contains(_Section.today);
  int get incomingToday => _incomingToday;
  int get outgoingToday => _outgoingToday;
  bool get isLoadingOpsToday => _loading.contains(_Section.opsToday);
  List<ReplenishmentNeed> get replenishmentNeeds => _replenishmentNeeds;
  bool get isLoadingReplenishment => _loading.contains(_Section.replenishment);

  /// Loads one [section]. A call while that section is loading is ignored
  /// unless [force]d, in which case it starts over and the running load's
  /// result is discarded (see [_latestLoad]).
  Future<void> _load<T>(
    _Section section, {
    required bool force,
    required Future<T> Function() fetch,
    required void Function(T value) onData,
    required void Function(Object error) onError,
    VoidCallback? onStart,
  }) async {
    if (_loading.contains(section) && !force) return;

    final load = (_latestLoad[section] ?? 0) + 1;
    _latestLoad[section] = load;
    _loading.add(section);
    onStart?.call();
    notifyListeners();

    try {
      final value = await fetch();
      if (_latestLoad[section] == load) onData(value);
    } catch (e) {
      if (_latestLoad[section] == load) onError(e);
    } finally {
      if (_latestLoad[section] == load) {
        _loading.remove(section);
        notifyListeners();
      }
    }
  }

  /// Fetches high-level dashboard statistics (warehouses, locations, orders, etc.).
  Future<void> fetchStats({bool forceRefresh = false}) => _load(
    _Section.stats,
    force: forceRefresh,
    onStart: () => _error = null,
    fetch: _service.fetchDashboardStats,
    onData: (stats) {
      _stats = stats;
      _error = null;
      _hasLoadedData = true;
    },
    onError: (e) {
      _error = OdooErrorMapper.toUserMessage(e);
      if (e is NoInternetException || e is ServerUnreachableException) {
        _stats = DashboardStats.empty();
        _hasLoadedData = false;
      }
    },
  );

  Future<void> fetchTodayOperationsCounts({bool forceRefresh = false}) => _load(
    _Section.opsToday,
    force: forceRefresh,
    fetch: () => Future.wait<int>([
      _service.fetchIncomingTodayCount(),
      _service.fetchOutgoingTodayCount(),
    ]),
    onData: (results) {
      _incomingToday = results[0];
      _outgoingToday = results[1];
    },
    onError: (_) {
      _incomingToday = 0;
      _outgoingToday = 0;
    },
  );

  Future<void> fetchRecentActivities({
    int limit = 10,
    bool forceRefresh = false,
  }) => _load(
    _Section.recent,
    force: forceRefresh,
    fetch: () => _service.fetchRecentActivities(limit: limit),
    onData: (items) => _recent = items,
    onError: (_) => _recent = const [],
  );

  Future<void> fetchNegativeQuants({
    int limit = 4,
    bool forceRefresh = false,
  }) => _load(
    _Section.negative,
    force: forceRefresh,
    fetch: () => _service.fetchNegativeQuants(limit: limit),
    onData: (items) => _negativeQuants = items,
    onError: (_) => _negativeQuants = const [],
  );

  Future<void> fetchTodayActivities({
    int limit = 4,
    bool forceRefresh = false,
  }) => _load(
    _Section.today,
    force: forceRefresh,
    fetch: () => _service.fetchTodayActivities(limit: limit),
    onData: (items) => _todayActivities = items,
    onError: (_) => _todayActivities = const [],
  );

  Future<void> fetchReplenishmentNeeds({
    int limit = 4,
    bool forceRefresh = false,
  }) => _load(
    _Section.replenishment,
    force: forceRefresh,
    fetch: () => _service.fetchReplenishmentNeeds(limit: limit),
    onData: (items) => _replenishmentNeeds = items,
    onError: (_) => _replenishmentNeeds = const [],
  );

  /// Refreshes all dashboard data components, superseding any load still
  /// running — e.g. one started before the company scope changed.
  Future<void> refreshAll() async {
    await Future.wait([
      fetchStats(forceRefresh: true),
      fetchTodayOperationsCounts(forceRefresh: true),
      fetchRecentActivities(limit: 4, forceRefresh: true),
      fetchNegativeQuants(limit: 4, forceRefresh: true),
      fetchTodayActivities(limit: 4, forceRefresh: true),
      fetchReplenishmentNeeds(limit: 4, forceRefresh: true),
    ]);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetState() {
    // Loads still running were started for the outgoing account.
    for (final section in _Section.values) {
      _latestLoad[section] = (_latestLoad[section] ?? 0) + 1;
    }
    _loading.clear();
    _stats = DashboardStats.empty();
    _error = null;
    _hasLoadedData = false;
    _recent = const [];
    _negativeQuants = const [];
    _todayActivities = const [];
    _incomingToday = 0;
    _outgoingToday = 0;
    _replenishmentNeeds = const [];
    notifyListeners();
  }
}
