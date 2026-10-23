import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appsession.dart';
import '../odoo/odoo_version.dart';
import 'odoo_session_manager.dart';
import 'session_service.dart';

/// One access question: may the current user perform [operation] on [model]?
///
/// [operation] is one of Odoo's CRUD operations: `read`, `create`, `write`,
/// `unlink`.
@immutable
class AccessCheck {
  const AccessCheck(this.model, this.operation);

  final String model;
  final String operation;

  static const Set<String> operations = {'read', 'create', 'write', 'unlink'};

  String get cacheKey => '$model|$operation';

  @override
  bool operator ==(Object other) =>
      other is AccessCheck &&
      other.model == model &&
      other.operation == operation;

  @override
  int get hashCode => Object.hash(model, operation);

  @override
  String toString() => 'AccessCheck($cacheKey)';
}

/// The account, and company within it, that access answers belong to.
@immutable
class AccessAccount {
  const AccessAccount({
    required this.serverUrl,
    required this.database,
    required this.userId,
    required this.companyId,
    this.serverMajor,
  });

  factory AccessAccount.fromSession(AppSessionData session) => AccessAccount(
    serverUrl: session.serverUrl,
    database: session.database,
    userId: session.userId,
    companyId: session.companyId,
    serverMajor: OdooVersion.parseMajor(session.odooSession.serverVersion),
  );

  final String serverUrl;
  final String database;
  final int userId;
  final int companyId;

  /// Odoo major version, when the session recorded one.
  final int? serverMajor;

  /// Answers are cached under this key, so another company re-checks.
  String get key => '$serverUrl|$database|$userId|$companyId';

  /// The signed-in user regardless of company, in the same shape
  /// `OdooSessionManager` uses for its committed-account key.
  String get identity => '$serverUrl|$database|$userId';

  String get serverKey => '$serverUrl|$database';
}

/// What a bottom-nav tab needs before it is shown.
///
/// [group] mirrors the `groups` of the Odoo menu that opens the same screen,
/// so a tab appears for exactly the users who see that menu in Odoo.
/// [reads] are the models the screen's own queries read; every one must be
/// readable, so a tab is never shown only to fail with an access error.
@immutable
class TabRequirement {
  const TabRequirement({this.group, this.reads = const []});

  final String? group;
  final List<String> reads;
}

/// Asks Odoo access questions over RPC.
///
/// Implementations throw on any failure — network, server error, unexpected
/// answer. [AccessRightsService] catches and fails open.
abstract class AccessRightsProbe {
  Future<bool> hasAccess(AccessAccount account, AccessCheck check);

  Future<bool> hasGroup(AccessAccount account, String groupXmlId);
}

typedef AccessCallKw = Future<dynamic> Function(Map<String, dynamic> payload);

/// [AccessRightsProbe] for Odoo 17 through 20.
///
/// * Model access: `has_access(operation)` on an empty recordset, which is
///   public from 18 on. Odoo 17 has no `has_access`, so it falls back to
///   `check_access_rights(operation, raise_exception=False)` — deprecated in
///   18 and gone in 20, where it raises `AttributeError`.
/// * Group membership: `res.users.has_group`, a record method from 18 on
///   (`args: [[uid], xmlid]`) but `@api.model` on 17 (`args: [xmlid]`). The
///   wrong shape raises `TypeError` on either side, so that triggers the
///   other one.
///
/// The server version picks which form goes first; a server whose version
/// is unknown is probed once and remembered.
class OdooAccessRightsProbe implements AccessRightsProbe {
  OdooAccessRightsProbe({AccessCallKw? callKw})
    : _callKw = callKw ?? OdooSessionManager.safeCallKwWithoutCompany;

  final AccessCallKw _callKw;

  /// Per server: true once it answered only to the Odoo 17 forms.
  final Map<String, bool> _legacyApi = {};

  bool _prefersLegacy(AccessAccount account) =>
      _legacyApi[account.serverKey] ??
      (account.serverMajor != null && account.serverMajor! < 18);

  @override
  Future<bool> hasAccess(AccessAccount account, AccessCheck check) {
    final modern = <String, dynamic>{
      'model': check.model,
      'method': 'has_access',
      'args': [<int>[], check.operation],
      'kwargs': <String, dynamic>{},
    };
    final legacy = <String, dynamic>{
      'model': check.model,
      'method': 'check_access_rights',
      'args': [check.operation],
      'kwargs': <String, dynamic>{'raise_exception': false},
    };
    return _answer(account, modern, legacy, isMissingMethodError);
  }

  @override
  Future<bool> hasGroup(AccessAccount account, String groupXmlId) {
    final modern = <String, dynamic>{
      'model': 'res.users',
      'method': 'has_group',
      'args': [
        [account.userId],
        groupXmlId,
      ],
      'kwargs': <String, dynamic>{},
    };
    final legacy = <String, dynamic>{
      'model': 'res.users',
      'method': 'has_group',
      'args': [groupXmlId],
      'kwargs': <String, dynamic>{},
    };
    return _answer(account, modern, legacy, isSignatureError);
  }

  Future<bool> _answer(
    AccessAccount account,
    Map<String, dynamic> modern,
    Map<String, dynamic> legacy,
    bool Function(Object error) tryOtherForm,
  ) async {
    final legacyFirst = _prefersLegacy(account);
    final first = legacyFirst ? legacy : modern;
    final second = legacyFirst ? modern : legacy;

    Object firstError;
    try {
      return _asBool(await _callKw(first));
    } catch (e) {
      if (!tryOtherForm(e)) rethrow;
      firstError = e;
    }

    try {
      final answer = _asBool(await _callKw(second));
      _legacyApi[account.serverKey] = !legacyFirst;
      return answer;
    } catch (_) {
      // The first form's error says more about why neither worked.
      throw firstError;
    }
  }

  static bool _asBool(dynamic result) {
    if (result is bool) return result;
    throw FormatException('Unexpected access answer: $result');
  }

  /// The method is not callable on this server version — it does not exist
  /// (`AttributeError ... does not exist`) or is private there.
  @visibleForTesting
  static bool isMissingMethodError(Object error) {
    final text = error.toString();
    return (text.contains('AttributeError') &&
            text.contains('does not exist')) ||
        text.contains('cannot be called remotely');
  }

  /// The method exists but was called with the other version's arguments.
  @visibleForTesting
  static bool isSignatureError(Object error) {
    final text = error.toString();
    return text.contains('TypeError') && text.contains('positional argument');
  }
}

/// Which of the shell's tabs, and later which actions, the signed-in user's
/// Odoo access rights allow.
///
/// Answers come from the server (see [OdooAccessRightsProbe]) and are cached
/// per account and company (`server|db|uid|company`), in memory and on disk,
/// so a relaunch or a switch back to an account shows its tabs at once while
/// they are re-checked. They are recomputed when the account or company
/// changes (followed through [SessionService]), when [ensureLoaded] finds
/// nothing loaded yet, and on [refresh].
///
/// **Fails open.** A question the server could not answer — offline,
/// timed out, unexpected error — is never taken as "no": it keeps the last
/// definite answer for this account, or allows when there is none. Tabs are
/// hidden only on a definite "no" from the server.
///
/// Use [can] / [inGroup] (synchronous, fail open, fetched lazily) to hide
/// actions; listen to this notifier to rebuild when answers arrive.
class AccessRightsService extends ChangeNotifier {
  AccessRightsService._internal({
    required AccessRightsProbe probe,
    required AccessAccount? Function() readAccount,
    Listenable? sessionChanges,
    Future<String?> Function()? liveIdentity,
    Duration timeout = const Duration(seconds: 15),
    bool persist = true,
  }) : _probe = probe,
       _readAccount = readAccount,
       _sessionChanges = sessionChanges,
       _liveIdentity = liveIdentity,
       _timeout = timeout,
       _persist = persist {
    _sessionChanges?.addListener(_onSessionChanged);
    // Deferred: the singleton is often first touched inside a build.
    scheduleMicrotask(_syncAccount);
  }

  static final AccessRightsService instance = AccessRightsService._internal(
    probe: OdooAccessRightsProbe(),
    readAccount: _accountFromSessionService,
    sessionChanges: SessionService.instance,
    liveIdentity: _liveIdentityFromSessionManager,
  );

  @visibleForTesting
  factory AccessRightsService.forTesting({
    required AccessRightsProbe probe,
    required AccessAccount? Function() readAccount,
    Listenable? sessionChanges,
    Future<String?> Function()? liveIdentity,
    Duration timeout = const Duration(seconds: 15),
    bool persist = false,
  }) => AccessRightsService._internal(
    probe: probe,
    readAccount: readAccount,
    sessionChanges: sessionChanges,
    liveIdentity: liveIdentity,
    timeout: timeout,
    persist: persist,
  );

  static AccessAccount? _accountFromSessionService() {
    final session = SessionService.instance.currentSession;
    return session == null ? null : AccessAccount.fromSession(session);
  }

  /// The account the session manager is actually talking to. It differs
  /// from [SessionService]'s while a candidate account is being tried
  /// (see `OdooSessionManager.beginProvisionalSession`), and answers given
  /// then belong to that candidate, not to the committed account.
  static Future<String?> _liveIdentityFromSessionManager() async {
    final session = await OdooSessionManager.getCurrentSession();
    return session == null
        ? null
        : '${session.serverUrl}|${session.database}|${session.userId}';
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  // Branch indices of MainShell's StatefulShellRoute.indexedStack, in the
  // order app_router.dart declares them.
  static const int dashboardBranch = 0;
  static const int inventoryBranch = 1;
  static const int transferBranch = 2;
  static const int replenishmentBranch = 3;
  static const int historyBranch = 4;
  static const int branchCount = 5;

  static const String stockUserGroup = 'stock.group_stock_user';
  static const String stockManagerGroup = 'stock.group_stock_manager';

  /// What each tab needs. Dashboard has no entry: it is always shown.
  ///
  /// Groups follow Odoo's own menus (identical in 17–20): the Inventory app
  /// root is for `stock.group_stock_user` (implied by the manager group),
  /// while Operations > Replenishment and Reporting > Moves History are
  /// `stock.group_stock_manager` only.
  ///
  /// Reads are the models each screen's list query touches. `stock.move` is
  /// listed for Inventory because `qty_available` & co. are computed from
  /// stock moves without sudo, and for History because its status, search
  /// and inventory filters traverse `move_id`: a user who cannot read
  /// `stock.move` gets an AccessError on both screens.
  static const Map<int, TabRequirement> tabRequirements = {
    inventoryBranch: TabRequirement(
      group: stockUserGroup,
      reads: ['product.product', 'stock.move'],
    ),
    transferBranch: TabRequirement(
      group: stockUserGroup,
      reads: ['stock.picking'],
    ),
    replenishmentBranch: TabRequirement(
      group: stockManagerGroup,
      reads: ['stock.warehouse.orderpoint'],
    ),
    historyBranch: TabRequirement(
      group: stockManagerGroup,
      reads: ['stock.move.line', 'stock.move'],
    ),
  };

  /// The branches to show, in branch order, given access answers. Dashboard
  /// is always first.
  static List<int> visibleBranchesFor({
    required bool Function(AccessCheck check) can,
    required bool Function(String groupXmlId) inGroup,
  }) {
    return [
      for (var branch = 0; branch < branchCount; branch++)
        if (_branchAllowed(branch, can, inGroup)) branch,
    ];
  }

  static bool _branchAllowed(
    int branch,
    bool Function(AccessCheck check) can,
    bool Function(String groupXmlId) inGroup,
  ) {
    if (branch == dashboardBranch) return true;
    final requirement = tabRequirements[branch];
    if (requirement == null) return true;
    final group = requirement.group;
    if (group != null && !inGroup(group)) return false;
    return requirement.reads.every(
      (model) => can(AccessCheck(model, 'read')),
    );
  }

  /// [current] when it is visible, otherwise the first visible branch.
  static int resolveBranch(int current, List<int> visible) {
    if (visible.contains(current)) return current;
    return visible.isEmpty ? dashboardBranch : visible.first;
  }

  static final List<AccessCheck> _tabChecks = [
    for (final model in {
      for (final requirement in tabRequirements.values) ...requirement.reads,
    })
      AccessCheck(model, 'read'),
  ];

  static final List<String> _tabGroups = [
    for (final group in {
      for (final requirement in tabRequirements.values)
        if (requirement.group != null) requirement.group!,
    })
      group,
  ];

  /// The branches the current user may open, in branch order.
  List<int> get visibleBranches => visibleBranchesFor(
    can: (check) => _answers[check.cacheKey] ?? true,
    inGroup: (group) => _answers[_groupKey(group)] ?? true,
  );

  bool isBranchVisible(int branch) => visibleBranches.contains(branch);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Whether the user may perform [operation] on [model]. Synchronous and
  /// fail open: true until the server has definitely said no.
  ///
  /// A pair not asked before is fetched in the background and listeners are
  /// notified when it arrives; [prefetch] starts that earlier.
  bool can(String model, String operation) {
    final check = AccessCheck(model, operation);
    final answer = _answers[check.cacheKey];
    if (answer == null) _fetchLazily(check.cacheKey);
    return answer ?? true;
  }

  /// Whether the user belongs to [groupXmlId] (e.g. `stock.group_stock_manager`),
  /// implied groups included. Same fail-open, lazy behaviour as [can].
  bool inGroup(String groupXmlId) {
    final key = _groupKey(groupXmlId);
    final answer = _answers[key];
    if (answer == null) _fetchLazily(key);
    return answer ?? true;
  }

  /// Like [can], but waits for the server when the pair is not cached yet.
  Future<bool> check(String model, String operation) =>
      _awaitAnswer(AccessCheck(model, operation).cacheKey);

  /// Like [inGroup], but waits for the server when not cached yet.
  Future<bool> checkGroup(String groupXmlId) =>
      _awaitAnswer(_groupKey(groupXmlId));

  /// Starts fetching [checks] (and [groups]) not cached yet, e.g. from a
  /// screen's `initState`, so [can] has answers by the time it is built.
  void prefetch(
    Iterable<AccessCheck> checks, {
    Iterable<String> groups = const [],
  }) {
    for (final check in checks) {
      if (!_answers.containsKey(check.cacheKey)) _fetchLazily(check.cacheKey);
    }
    for (final group in groups) {
      final key = _groupKey(group);
      if (!_answers.containsKey(key)) _fetchLazily(key);
    }
  }

  /// Whether the user may apply an inventory adjustment
  /// (`stock.quant.action_apply_inventory`).
  ///
  /// Odoo 16/17 refuse it outright for non-managers (`_apply_inventory`
  /// raises "Only a stock manager can validate an inventory adjustment.");
  /// 18+ dropped that check, leaving the quant write and the stock move it
  /// creates.
  bool get canApplyInventoryAdjustment {
    final acl = can('stock.quant', 'write') && can('stock.move', 'create');
    final major = _account?.serverMajor;
    if (major != null && major <= 17) {
      return acl && inGroup(stockManagerGroup);
    }
    return acl;
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final AccessRightsProbe _probe;
  final AccessAccount? Function() _readAccount;
  final Listenable? _sessionChanges;
  final Future<String?> Function()? _liveIdentity;
  final Duration _timeout;
  final bool _persist;

  static const String _prefsKey = 'access_rights_cache_v1';
  static const int _maxCachedAccounts = 10;

  AccessAccount? _account;

  /// Definite answers for [_account], keyed by [AccessCheck.cacheKey] or
  /// [_groupKey]. A missing key means "not known" — allowed.
  Map<String, bool> _answers = {};

  /// Definite answers per account key, most recently used last (map
  /// literals keep insertion order).
  final Map<String, Map<String, bool>> _cache = {};

  final Map<String, Future<bool?>> _lazyFutures = {};
  final Set<String> _lazyFailed = {};

  /// Bumped on every account change; work started for an older generation
  /// is dropped when it finishes.
  int _generation = 0;
  Future<void>? _refreshing;
  String? _loadedKey;
  bool _lastRunIncomplete = false;
  bool _persistedRestored = false;
  bool _disposed = false;

  /// The account (and company) the answers are for.
  AccessAccount? get account => _account;

  /// True once the server has answered for the current account in this run
  /// of the app (not just from the on-disk cache).
  bool get isLoaded => _account != null && _loadedKey == _account!.key;

  static String _groupKey(String groupXmlId) => 'group:$groupXmlId';

  void _onSessionChanged() {
    // Not inline: this fires while the session service is still notifying.
    scheduleMicrotask(_syncAccount);
  }

  void _syncAccount() {
    if (_disposed) return;
    final next = _readAccount();
    if (next?.key == _account?.key) return;

    _account = next;
    _generation++;
    _refreshing = null;
    _loadedKey = null;
    _lastRunIncomplete = false;
    _lazyFutures.clear();
    _lazyFailed.clear();
    _answers = next == null
        ? <String, bool>{}
        : Map<String, bool>.of(_cache[next.key] ?? const {});
    notifyListeners();

    if (next != null) unawaited(refresh());
  }

  /// Makes sure answers for the current account are loaded or loading.
  /// Call on app start (e.g. when the shell first appears).
  Future<void> ensureLoaded() {
    _syncAccount();
    if (_account == null) return Future.value();
    if (isLoaded && !_lastRunIncomplete) return Future.value();
    return refresh();
  }

  /// Re-asks the server everything known for the current account: the tab
  /// requirements and every action asked about so far. Concurrent calls
  /// share one run.
  Future<void> refresh() {
    final account = _account;
    if (account == null || _disposed) return Future.value();
    final running = _refreshing;
    if (running != null) return running;

    late final Future<void> future;
    future = _run(_generation, account).whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
    _refreshing = future;
    return future;
  }

  Future<void> _run(int generation, AccessAccount account) async {
    bool current() => !_disposed && generation == _generation;

    await _restorePersisted();
    if (!current()) return;
    if (_answers.isEmpty) {
      final cached = _cache[account.key];
      if (cached != null && cached.isNotEmpty) {
        _answers = Map<String, bool>.of(cached);
        notifyListeners();
      }
    }

    if (!await _isLive(account) || !current()) {
      _lastRunIncomplete = true;
      return;
    }

    final asks = <String, Future<bool> Function()>{
      for (final check in _tabChecks)
        check.cacheKey: () => _probe.hasAccess(account, check),
      for (final group in _tabGroups)
        _groupKey(group): () => _probe.hasGroup(account, group),
    };
    for (final key in _answers.keys) {
      if (asks.containsKey(key)) continue;
      final ask = _askFor(account, key);
      if (ask != null) asks[key] = ask;
    }

    final keys = asks.keys.toList();
    final results = await Future.wait(keys.map((key) => _guarded(asks[key]!)));
    if (!current()) return;
    // Answers given while another account was being tried are that
    // account's, not this one's.
    if (!await _isLive(account) || !current()) {
      _lastRunIncomplete = true;
      return;
    }

    var incomplete = false;
    for (var i = 0; i < keys.length; i++) {
      final answer = results[i];
      if (answer == null) {
        // Fail open: keep the last definite answer, or none (= allowed).
        incomplete = true;
        continue;
      }
      _answers[keys[i]] = answer;
    }
    _lastRunIncomplete = incomplete;
    _loadedKey = account.key;
    _lazyFailed.clear();
    _remember(account);
    notifyListeners();
  }

  Future<bool> Function()? _askFor(AccessAccount account, String key) {
    if (key.startsWith('group:')) {
      final group = key.substring('group:'.length);
      return () => _probe.hasGroup(account, group);
    }
    final separator = key.lastIndexOf('|');
    if (separator <= 0) return null;
    final check = AccessCheck(
      key.substring(0, separator),
      key.substring(separator + 1),
    );
    if (!AccessCheck.operations.contains(check.operation)) return null;
    return () => _probe.hasAccess(account, check);
  }

  /// The answer, or null when the question could not be answered.
  Future<bool?> _guarded(Future<bool> Function() ask) async {
    try {
      return await ask().timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isLive(AccessAccount account) async {
    final liveIdentity = _liveIdentity;
    if (liveIdentity == null) return true;
    try {
      final identity = await liveIdentity();
      return identity == null || identity == account.identity;
    } catch (_) {
      return true;
    }
  }

  void _fetchLazily(String key) {
    if (_disposed) return;
    if (_lazyFutures.containsKey(key) || _lazyFailed.contains(key)) return;
    unawaited(_fetchOne(key));
  }

  Future<bool> _awaitAnswer(String key) async {
    final known = _answers[key];
    if (known != null) return known;
    return await _fetchOne(key) ?? true;
  }

  /// Fetches one answer for the current account; null when it could not be
  /// answered (or the account changed meanwhile). Concurrent callers share
  /// one request.
  Future<bool?> _fetchOne(String key) {
    final account = _account;
    if (account == null || _disposed) return Future.value(null);
    final existing = _lazyFutures[key];
    if (existing != null) return existing;
    final ask = _askFor(account, key);
    if (ask == null) return Future.value(null);

    final future = _fetchFor(key, account, ask, _generation);
    _lazyFutures[key] = future;
    return future;
  }

  Future<bool?> _fetchFor(
    String key,
    AccessAccount account,
    Future<bool> Function() ask,
    int generation,
  ) async {
    bool current() => !_disposed && generation == _generation;

    final answer = await _guarded(ask);
    if (current()) _lazyFutures.remove(key);
    if (!current() || !await _isLive(account) || !current()) return null;
    if (answer == null) {
      // Not retried until the next refresh, so a screen rebuilding while
      // offline does not fire a request per frame.
      _lazyFailed.add(key);
      return null;
    }
    final changed = _answers[key] != answer;
    _answers[key] = answer;
    _remember(account);
    if (changed) notifyListeners();
    return answer;
  }

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  void _remember(AccessAccount account) {
    _cache.remove(account.key);
    _cache[account.key] = Map<String, bool>.of(_answers);
    while (_cache.length > _maxCachedAccounts) {
      _cache.remove(_cache.keys.first);
    }
    unawaited(_savePersisted());
  }

  Future<void> _restorePersisted() async {
    if (!_persist || _persistedRestored) return;
    _persistedRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final restored = <String, Map<String, bool>>{};
      decoded.forEach((accountKey, answers) {
        if (answers is! Map) return;
        restored[accountKey.toString()] = {
          for (final entry in answers.entries)
            if (entry.value is bool) entry.key.toString(): entry.value as bool,
        };
      });
      // Answers fetched while the disk read was pending are fresher.
      for (final entry in restored.entries) {
        _cache.putIfAbsent(entry.key, () => entry.value);
      }
    } catch (_) {
      // A cache that cannot be read is just a cold start.
    }
  }

  Future<void> _savePersisted() async {
    if (!_persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_cache));
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionChanges?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
