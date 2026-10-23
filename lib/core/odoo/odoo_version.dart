import '../models/appsession.dart';
import '../services/odoo_session_manager.dart';

/// Resolves the major version of the connected Odoo server.
///
/// The app talks to Odoo 16 through 20, which rename fields between releases.
/// Version-dependent decisions go through [OdooCompat] rather than inspecting
/// version strings inline — checks such as `serverVersion.contains("17")`
/// silently misclassify every other release.
class OdooVersion {
  OdooVersion._();

  static const int minSupported = 16;
  static const int maxSupported = 20;

  /// Used when no session records a version and the server cannot be asked.
  static const int fallbackMajor = 18;

  /// Handles the shapes Odoo actually reports: `16.0`, `16.0+e`,
  /// `17.0-20240101`, and the SaaS form `saas~16.3`.
  static int? parseMajor(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    // `saas~16.3` must yield 16, so take the first run of digits.
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    final major = int.tryParse(match.group(1)!);
    if (major == null || major <= 0) return null;
    return major;
  }

  static final Map<String, int> _resolved = {};
  static String? _discoveryKey;
  static Future<int>? _discovery;

  static String _identityOf(AppSessionData s) =>
      '${s.serverUrl}|${s.database}|${s.userId}';

  static Future<int> major() async {
    AppSessionData? session;
    try {
      session = await OdooSessionManager.getCurrentSession();
    } catch (_) {
      return fallbackMajor;
    }
    if (session == null) return fallbackMajor;

    final parsed = parseMajor(session.odooSession.serverVersion);
    if (parsed != null) return parsed;

    final cached = _resolved[_identityOf(session)];
    if (cached != null) return cached;

    return _discover(session);
  }

  static Future<int> _discover(AppSessionData session) {
    final key = _identityOf(session);
    final inFlight = _discovery;
    if (inFlight != null && _discoveryKey == key) return inFlight;

    final future = _queryServerVersion(session);
    _discoveryKey = key;
    _discovery = future;
    // Cleared once it settles, so this only ever deduplicates *concurrent*
    // callers. A probe that failed writes nothing to [_resolved], and holding
    // its completed future here would hand every later caller the fallback for
    // the rest of the session — on a 19 server that silently routes `phone` to
    // res.partner forever.
    future.whenComplete(() {
      if (identical(_discovery, future)) {
        _discovery = null;
        _discoveryKey = null;
      }
    });
    return future;
  }

  static Future<int> _queryServerVersion(AppSessionData session) async {
    try {
      // Without company context: the version is a property of the database,
      // not of whichever company happens to be selected.
      final result = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'ir.module.module',
        'method': 'search_read',
        'args': [
          [
            ['name', '=', 'base'],
          ],
          ['latest_version'],
        ],
        'kwargs': {'limit': 1},
      });

      if (result is List && result.isNotEmpty) {
        // `base` reports e.g. '16.0.1.3', so the leading number is the release.
        final raw = (result.first as Map)['latest_version'];
        final parsed = parseMajor(raw is String ? raw : null);
        if (parsed != null) {
          _resolved[_identityOf(session)] = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // fall through to the documented default
    }
    return fallbackMajor;
  }

  /// Drops every resolved version. Call on logout or account switch.
  static void reset() {
    _resolved.clear();
    _discoveryKey = null;
    _discovery = null;
  }
}
