import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers keyed like the service's cache: `model|operation` or
/// `group:<xmlid>`. A key that is absent is allowed.
typedef Answers = Map<String, bool>;

/// What `has_access` / `has_group` return on the local Odoo 20 server
/// (ENT_20) for its three kinds of user.
const Answers inventoryAdministrator = {}; // admin "1": everything allowed

const Answers inventoryUser = {
  // demo: stock.group_stock_user (+ sales, mrp user)
  'group:stock.group_stock_manager': false,
  'product.template|create': false,
  'product.template|write': false,
  'stock.warehouse.orderpoint|write': false,
};

const Answers noInventoryRights = {
  // light: base.group_user only
  'group:stock.group_stock_user': false,
  'group:stock.group_stock_manager': false,
  'product.product|read': true,
  'stock.move|read': false,
  'stock.picking|read': false,
  'stock.warehouse.orderpoint|read': false,
  'stock.move.line|read': true,
  'stock.quant|write': false,
};

const allBranches = [0, 1, 2, 3, 4];

const accountA = AccessAccount(
  serverUrl: 'https://a.example.com',
  database: 'db',
  userId: 2,
  companyId: 1,
  serverMajor: 20,
);
const accountB = AccessAccount(
  serverUrl: 'https://a.example.com',
  database: 'db',
  userId: 6,
  companyId: 1,
  serverMajor: 20,
);

class FakeProbe implements AccessRightsProbe {
  FakeProbe(this.answer);

  /// The answer for [key] on [account]; null makes the call fail.
  bool? Function(AccessAccount account, String key) answer;

  /// Calls for a user id wait on its gate while one is set.
  final Map<int, Completer<void>> gates = {};
  final List<String> calls = [];

  Future<bool> _respond(AccessAccount account, String key) async {
    calls.add('${account.key}#$key');
    final gate = gates[account.userId];
    if (gate != null) await gate.future;
    final result = answer(account, key);
    if (result == null) throw Exception('server unreachable');
    return result;
  }

  @override
  Future<bool> hasAccess(AccessAccount account, AccessCheck check) =>
      _respond(account, check.cacheKey);

  @override
  Future<bool> hasGroup(AccessAccount account, String groupXmlId) =>
      _respond(account, 'group:$groupXmlId');
}

bool? Function(AccessAccount, String) fixed(Answers answers) =>
    (_, key) => answers[key] ?? true;

bool? Function(AccessAccount, String) perUser(Map<int, Answers> byUser) =>
    (account, key) => byUser[account.userId]?[key] ?? true;

bool? failing(AccessAccount account, String key) => null;

/// Lets the service's microtasks and awaits run to completion.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class Harness {
  Harness(
    this.probe, {
    AccessAccount? account = accountA,
    Duration timeout = const Duration(seconds: 15),
    bool persist = false,
    this.liveIdentity,
  }) : current = account {
    service = AccessRightsService.forTesting(
      probe: probe,
      readAccount: () => current,
      sessionChanges: session,
      liveIdentity: liveIdentity == null ? null : () async => liveIdentity,
      timeout: timeout,
      persist: persist,
    );
  }

  final FakeProbe probe;
  final ValueNotifier<int> session = ValueNotifier(0);
  AccessAccount? current;
  String? liveIdentity;
  late final AccessRightsService service;

  /// Simulates SessionService notifying about a (possibly) new session.
  void switchTo(AccessAccount? account) {
    current = account;
    session.value++;
  }

  void dispose() => service.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibleBranchesFor', () {
    List<int> visible(Answers answers) =>
        AccessRightsService.visibleBranchesFor(
          can: (check) => answers[check.cacheKey] ?? true,
          inGroup: (group) => answers['group:$group'] ?? true,
        );

    test('an inventory administrator gets every tab', () {
      expect(visible(inventoryAdministrator), allBranches);
    });

    test('an inventory user loses Replenish and History, as in Odoo', () {
      // Odoo shows Operations > Replenishment and Reporting > Moves History
      // to stock.group_stock_manager only.
      expect(visible(inventoryUser), [0, 1, 2]);
    });

    test('a user without inventory rights keeps only the Dashboard', () {
      expect(visible(noInventoryRights), [0]);
    });

    test('Dashboard stays even when every check says no', () {
      expect(
        AccessRightsService.visibleBranchesFor(
          can: (_) => false,
          inGroup: (_) => false,
        ),
        [0],
      );
    });

    test('a model the tab reads that is not readable hides it', () {
      expect(visible({'stock.picking|read': false}), [0, 1, 3, 4]);
      expect(visible({'stock.warehouse.orderpoint|read': false}), [
        0,
        1,
        2,
        4,
      ]);
    });

    test('stock.move is required by both Inventory and History', () {
      // qty_available is computed from stock moves; History filters on
      // move_id. Without stock.move read both screens raise AccessError.
      expect(visible({'stock.move|read': false}), [0, 2, 3]);
    });
  });

  group('resolveBranch', () {
    test('keeps a visible branch', () {
      expect(AccessRightsService.resolveBranch(2, [0, 1, 2]), 2);
    });

    test('moves a hidden branch to the first visible one', () {
      expect(AccessRightsService.resolveBranch(3, [0, 1, 2]), 0);
      expect(AccessRightsService.resolveBranch(4, [0]), 0);
    });

    test('falls back to Dashboard with nothing visible', () {
      expect(AccessRightsService.resolveBranch(3, const []), 0);
    });
  });

  group('AccessRightsService', () {
    test('shows every tab until the server answers', () async {
      final probe = FakeProbe(fixed(noInventoryRights));
      probe.gates[accountA.userId] = Completer<void>();
      final h = Harness(probe);
      addTearDown(h.dispose);

      await settle();
      expect(h.service.isLoaded, isFalse);
      expect(h.service.visibleBranches, allBranches);

      probe.gates[accountA.userId]!.complete();
      await settle();
      expect(h.service.isLoaded, isTrue);
      expect(h.service.visibleBranches, [0]);
    });

    test('hides the tabs the server denies', () async {
      final h = Harness(FakeProbe(fixed(inventoryUser)));
      addTearDown(h.dispose);

      await h.service.ensureLoaded();
      expect(h.service.visibleBranches, [0, 1, 2]);
      expect(h.service.isBranchVisible(3), isFalse);
    });

    test('asks for every tab requirement in one parallel wave', () async {
      final probe = FakeProbe(fixed(inventoryAdministrator));
      probe.gates[accountA.userId] = Completer<void>();
      final h = Harness(probe);
      addTearDown(h.dispose);

      await settle();
      // All issued before any answered: nothing waits on another call.
      expect(
        probe.calls.map((c) => c.split('#').last),
        unorderedEquals([
          'product.product|read',
          'stock.move|read',
          'stock.picking|read',
          'stock.warehouse.orderpoint|read',
          'stock.move.line|read',
          'group:stock.group_stock_user',
          'group:stock.group_stock_manager',
        ]),
      );
      probe.gates[accountA.userId]!.complete();
    });

    test('fails open when every check errors', () async {
      final h = Harness(FakeProbe(failing));
      addTearDown(h.dispose);

      await h.service.ensureLoaded();
      expect(h.service.visibleBranches, allBranches);
      expect(h.service.can('stock.picking', 'create'), isTrue);
      expect(
        h.service.inGroup(AccessRightsService.stockManagerGroup),
        isTrue,
      );
    });

    test('fails open when the server does not answer in time', () async {
      final probe = FakeProbe(fixed(noInventoryRights));
      probe.gates[accountA.userId] = Completer<void>(); // never completes
      final h = Harness(probe, timeout: const Duration(milliseconds: 20));
      addTearDown(h.dispose);

      await h.service.ensureLoaded();
      expect(h.service.visibleBranches, allBranches);
    });

    test('a failed re-check keeps the last definite answer', () async {
      final probe = FakeProbe(fixed(inventoryUser));
      final h = Harness(probe);
      addTearDown(h.dispose);
      await h.service.ensureLoaded();
      expect(h.service.visibleBranches, [0, 1, 2]);

      probe.answer = failing;
      await h.service.refresh();
      // The server said no before; a blip now is not a yes, nor a new no.
      expect(h.service.visibleBranches, [0, 1, 2]);
    });

    test('re-checks on account change and ignores the old account\'s '
        'late answers', () async {
      final probe = FakeProbe(
        perUser({
          accountA.userId: inventoryUser,
          accountB.userId: noInventoryRights,
        }),
      );
      probe.gates[accountA.userId] = Completer<void>();
      final h = Harness(probe);
      addTearDown(h.dispose);
      await settle();

      h.switchTo(accountB);
      await settle();
      expect(h.service.account, accountB);
      expect(h.service.visibleBranches, [0]);

      // Account A's answers arrive after the switch: they must not apply.
      probe.gates[accountA.userId]!.complete();
      await settle();
      expect(h.service.visibleBranches, [0]);
    });

    test('a company change re-checks; a same-account notification does '
        'not', () async {
      final probe = FakeProbe(fixed(inventoryAdministrator));
      final h = Harness(probe);
      addTearDown(h.dispose);
      await h.service.ensureLoaded();
      final initialCalls = probe.calls.length;

      h.switchTo(accountA); // e.g. a silent re-auth
      await settle();
      expect(probe.calls.length, initialCalls);

      const otherCompany = AccessAccount(
        serverUrl: 'https://a.example.com',
        database: 'db',
        userId: 2,
        companyId: 3,
        serverMajor: 20,
      );
      h.switchTo(otherCompany);
      await settle();
      expect(probe.calls.length, greaterThan(initialCalls));
      expect(probe.calls.last, startsWith(otherCompany.key));
    });

    test('switching back to an account shows its cached tabs at once', () async {
      final probe = FakeProbe(
        perUser({
          accountA.userId: inventoryUser,
          accountB.userId: inventoryAdministrator,
        }),
      );
      final h = Harness(probe);
      addTearDown(h.dispose);
      await h.service.ensureLoaded();
      h.switchTo(accountB);
      await settle();

      probe.gates[accountA.userId] = Completer<void>();
      h.switchTo(accountA);
      await settle();
      expect(h.service.isLoaded, isFalse); // still re-checking...
      expect(h.service.visibleBranches, [0, 1, 2]); // ...but already right
      probe.gates[accountA.userId]!.complete();
    });

    test('signing out clears the answers', () async {
      final h = Harness(FakeProbe(fixed(noInventoryRights)));
      addTearDown(h.dispose);
      await h.service.ensureLoaded();
      expect(h.service.visibleBranches, [0]);

      h.switchTo(null);
      await settle();
      expect(h.service.account, isNull);
      expect(h.service.visibleBranches, allBranches);
    });

    test('drops answers given while another account is being tried', () async {
      // OdooSessionManager is talking to a candidate account (provisional
      // switch) while SessionService still holds account A.
      final h = Harness(
        FakeProbe(fixed(noInventoryRights)),
        liveIdentity: accountB.identity,
      );
      addTearDown(h.dispose);

      await h.service.ensureLoaded();
      expect(h.service.isLoaded, isFalse);
      expect(h.service.visibleBranches, allBranches);
    });

    test('can() fetches an unknown pair lazily and notifies', () async {
      final probe = FakeProbe(fixed(inventoryUser));
      final h = Harness(probe);
      addTearDown(h.dispose);
      await h.service.ensureLoaded();
      var notified = 0;
      h.service.addListener(() => notified++);

      expect(h.service.can('product.template', 'create'), isTrue);
      await settle();
      expect(h.service.can('product.template', 'create'), isFalse);
      expect(notified, 1);

      // ...and from then on it is re-validated with the tabs.
      probe.calls.clear();
      await h.service.refresh();
      expect(
        probe.calls,
        contains('${accountA.key}#product.template|create'),
      );
    });

    test('check() waits for the server and fails open', () async {
      final probe = FakeProbe(fixed(inventoryUser));
      final h = Harness(probe);
      addTearDown(h.dispose);
      await h.service.ensureLoaded();

      expect(await h.service.check('stock.warehouse.orderpoint', 'write'),
          isFalse);
      probe.answer = failing;
      expect(await h.service.check('stock.picking', 'unlink'), isTrue);
    });

    test('applying an inventory adjustment needs a stock manager on 17 '
        'only', () async {
      Future<bool> canApply(int major) async {
        final account = AccessAccount(
          serverUrl: 'https://x',
          database: 'db',
          userId: 5,
          companyId: 1,
          serverMajor: major,
        );
        final h = Harness(FakeProbe(fixed(inventoryUser)), account: account);
        h.service.prefetch(
          const [
            AccessCheck('stock.quant', 'write'),
            AccessCheck('stock.move', 'create'),
          ],
          groups: const [AccessRightsService.stockManagerGroup],
        );
        await h.service.ensureLoaded();
        await settle();
        final result = h.service.canApplyInventoryAdjustment;
        h.dispose();
        return result;
      }

      expect(await canApply(17), isFalse);
      expect(await canApply(18), isTrue);
      expect(await canApply(20), isTrue);
    });

    test('persists answers per account and restores them on a cold '
        'start', () async {
      SharedPreferences.setMockInitialValues({});
      final first = Harness(FakeProbe(fixed(inventoryUser)), persist: true);
      await first.service.ensureLoaded();
      await settle();
      first.dispose();

      final probe = FakeProbe(fixed(inventoryUser));
      probe.gates[accountA.userId] = Completer<void>();
      final second = Harness(probe, persist: true);
      addTearDown(second.dispose);
      await settle();
      expect(second.service.isLoaded, isFalse);
      expect(second.service.visibleBranches, [0, 1, 2]);
      probe.gates[accountA.userId]!.complete();
    });
  });

  group('OdooAccessRightsProbe', () {
    OdooException odooError(String name, String message) => OdooException({
      'code': 200,
      'message': 'Odoo Server Error',
      'data': {'name': name, 'message': message},
    });

    AccessAccount account({int? major}) => AccessAccount(
      serverUrl: 'https://x',
      database: 'db',
      userId: 5,
      companyId: 1,
      serverMajor: major,
    );

    test('asks has_access on an empty recordset on 18+', () async {
      final payloads = <Map<String, dynamic>>[];
      final probe = OdooAccessRightsProbe(
        callKw: (payload) async {
          payloads.add(payload);
          return false;
        },
      );

      final result = await probe.hasAccess(
        account(major: 20),
        const AccessCheck('stock.picking', 'read'),
      );
      expect(result, isFalse);
      expect(payloads.single['model'], 'stock.picking');
      expect(payloads.single['method'], 'has_access');
      expect(payloads.single['args'], [<int>[], 'read']);
    });

    test('asks check_access_rights without raising on 17', () async {
      final payloads = <Map<String, dynamic>>[];
      final probe = OdooAccessRightsProbe(
        callKw: (payload) async {
          payloads.add(payload);
          return true;
        },
      );

      await probe.hasAccess(
        account(major: 17),
        const AccessCheck('stock.quant', 'write'),
      );
      expect(payloads.single['method'], 'check_access_rights');
      expect(payloads.single['args'], ['write']);
      expect(payloads.single['kwargs'], {'raise_exception': false});
    });

    test('falls back to check_access_rights when has_access does not '
        'exist, and remembers it', () async {
      final methods = <String>[];
      final probe = OdooAccessRightsProbe(
        callKw: (payload) async {
          methods.add(payload['method'] as String);
          if (payload['method'] == 'has_access') {
            // Odoo 17's call_kw wording.
            throw odooError(
              'builtins.AttributeError',
              "The method 'has_access' does not exist on the model "
                  "'stock.picking'",
            );
          }
          return false;
        },
      );
      final unknownVersion = account();

      expect(
        await probe.hasAccess(
          unknownVersion,
          const AccessCheck('stock.picking', 'read'),
        ),
        isFalse,
      );
      expect(methods, ['has_access', 'check_access_rights']);

      methods.clear();
      await probe.hasAccess(
        unknownVersion,
        const AccessCheck('stock.move', 'read'),
      );
      expect(methods, ['check_access_rights']);
    });

    test('falls back to has_access when check_access_rights is gone', () async {
      final methods = <String>[];
      final probe = OdooAccessRightsProbe(
        callKw: (payload) async {
          methods.add(payload['method'] as String);
          if (payload['method'] == 'check_access_rights') {
            // Odoo 20's wording, verified on the local server.
            throw odooError(
              'builtins.AttributeError',
              "The method 'stock.picking.check_access_rights' does not exist",
            );
          }
          return true;
        },
      );

      expect(
        await probe.hasAccess(
          account(major: 17), // misreported version
          const AccessCheck('stock.picking', 'read'),
        ),
        isTrue,
      );
      expect(methods, ['check_access_rights', 'has_access']);
    });

    test('other errors are not retried with the other method', () async {
      var calls = 0;
      final probe = OdooAccessRightsProbe(
        callKw: (_) async {
          calls++;
          throw Exception('SocketException: Connection refused');
        },
      );

      await expectLater(
        probe.hasAccess(
          account(major: 20),
          const AccessCheck('stock.picking', 'read'),
        ),
        throwsException,
      );
      expect(calls, 1);
    });

    test('rejects an answer that is not a boolean', () async {
      final probe = OdooAccessRightsProbe(callKw: (_) async => null);
      await expectLater(
        probe.hasAccess(
          account(major: 20),
          const AccessCheck('stock.picking', 'read'),
        ),
        throwsFormatException,
      );
    });

    test('has_group: record form on 18+, model form on 17, and the other '
        'form on a TypeError', () async {
      final args = <List<dynamic>>[];
      Future<dynamic> server(Map<String, dynamic> payload, {required int v}) {
        final a = payload['args'] as List;
        args.add(a);
        final recordForm = a.length == 2;
        if (recordForm != (v >= 18)) {
          throw odooError(
            'builtins.TypeError',
            v >= 18
                ? "ResUsers.has_group() missing 1 required positional "
                      "argument: 'group_ext_id'"
                : 'has_group() takes 2 positional arguments but 3 were given',
          );
        }
        return Future.value(true);
      }

      final modern = OdooAccessRightsProbe(callKw: (p) => server(p, v: 20));
      expect(
        await modern.hasGroup(account(major: 20), 'stock.group_stock_manager'),
        isTrue,
      );
      expect(args.single, [
        [5],
        'stock.group_stock_manager',
      ]);

      args.clear();
      final legacy = OdooAccessRightsProbe(callKw: (p) => server(p, v: 17));
      expect(
        await legacy.hasGroup(account(major: 17), 'stock.group_stock_manager'),
        isTrue,
      );
      expect(args.single, ['stock.group_stock_manager']);

      args.clear();
      final unknown = OdooAccessRightsProbe(callKw: (p) => server(p, v: 17));
      expect(
        await unknown.hasGroup(account(), 'stock.group_stock_manager'),
        isTrue,
      );
      expect(args, [
        [
          [5],
          'stock.group_stock_manager',
        ],
        ['stock.group_stock_manager'],
      ]);
    });
  });
}
