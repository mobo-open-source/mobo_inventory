import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Drives Odoo's two-factor login over plain HTTP instead of an embedded
/// browser.
///
/// The web client's 2FA login is three ordinary form requests, so there is no
/// need to render the login pages to complete it:
///
///  1. `GET /web/login?db=<db>` — starts a session (Odoo bounces once to set
///     the `session_id` cookie for the requested database) and carries the
///     CSRF token in a hidden field.
///  2. `POST /web/login` — on a correct password for a user with 2FA on,
///     Odoo stores a *partial* session (`pre_uid`, not yet authenticated) and
///     answers `303 /web/login/totp`.
///  3. `POST /web/login/totp` — on a correct code, `Session.finalize` turns
///     the partial session into a real one, rotates the session id and
///     answers `303 /web` (or `/odoo` on 18+). The rotated id arrives in that
///     response's `Set-Cookie`, and is the session this app then uses.
///
/// All of this was checked against the real controllers and templates on
/// Odoo 16 through 19 (`addons/web/controllers/home.py`,
/// `addons/auth_totp/controllers/home.py`, `addons/auth_totp/views/
/// templates.xml`); the routes, form field names and redirect targets are
/// identical on all four, and every MFA variant (`auth_totp`,
/// `auth_totp_mail`, `auth_totp_mail_enforce`) posts to `/web/login/totp`.
///
/// Steps 1 and 2 do not need the user's code, so they run while the OTP
/// screen is still being read — by the time a code is typed, only step 3 is
/// left. Anything this client does not recognise raises
/// [TotpHandshakeUnsupported] so the caller can fall back to the WebView,
/// which can drive whatever the server actually serves.
class OdooTotpHttpClient {
  OdooTotpHttpClient({
    required String serverUrl,
    required this.database,
    this.timeout = const Duration(seconds: 20),
  }) : _base = _parseBase(serverUrl);

  /// The Odoo database to authenticate against.
  final String database;

  /// Applied to each individual request, not to the flow as a whole.
  final Duration timeout;

  final Uri _base;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    // Keeps the connection open between the handshake and the code
    // submission, so submitting a code costs one round trip and no new TLS
    // negotiation.
    ..idleTimeout = const Duration(seconds: 60)
    // Self-signed certificates are accepted for the same reason the rest of
    // this app accepts them (the database lookup in `login_provider.dart`,
    // and the WebView's own `ServerTrustAuthResponseAction.PROCEED`):
    // on-premise Odoo servers are routinely deployed behind one, and
    // refusing here would push every such server onto the slow fallback.
    ..badCertificateCallback = (cert, host, port) => true;

  /// The cookie jar for this flow only. It is deliberately *not* shared with
  /// the rest of the app, and deliberately never seeded from the system
  /// cookie store: a `td_id` ("don't ask again on this device") cookie that
  /// Odoo already trusts would let `GET /web/login/totp` finalize a session
  /// without a code, which would turn a device Odoo remembers into a
  /// verification this screen never actually performed.
  final Map<String, String> _cookies = {};

  String? _csrfToken;
  Uri? _totpUrl;
  bool _closed = false;

  static const String _sessionCookie = 'session_id';
  static const String _trustedDeviceCookie = 'td_id';
  static const int _maxRedirects = 5;

  /// A desktop user agent: some reverse proxies in front of Odoo serve a
  /// stripped-down or redirecting page to unknown clients.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// Runs steps 1 and 2 — everything that can be done before the user has
  /// typed a code.
  ///
  /// Throws [TotpHandshakeUnsupported] when the server's login flow is not
  /// the standard Odoo one, and the usual [SocketException] /
  /// [HandshakeException] / [TimeoutException] when it cannot be reached.
  Future<TotpHandshake> begin({
    required String login,
    required String password,
  }) async {
    final loginPage = await _follow(
      'GET',
      _url('/web/login', {'db': database}),
    );

    if (_isDatabaseManagerUrl(loginPage.uri)) {
      // The database this app was given isn't one this server will serve
      // without a manual pick. Not something to answer blind with the user's
      // password.
      throw const TotpHandshakeUnsupported(
        'the server asked for a database to be selected',
      );
    }

    if (loginPage.statusCode != 200) {
      throw TotpHandshakeUnsupported(
        'the login page answered HTTP ${loginPage.statusCode}',
      );
    }

    final csrfToken = _extractCsrfToken(loginPage.body);
    if (csrfToken == null || !_looksLikeOdooLoginForm(loginPage.body)) {
      throw const TotpHandshakeUnsupported(
        'the server does not serve a standard Odoo login form',
      );
    }
    _csrfToken = csrfToken;

    final posted = await _send(
      'POST',
      _url('/web/login'),
      form: {
        'csrf_token': csrfToken,
        'login': login,
        'password': password,
        'db': database,
        // Odoo 18/19 read the credential type off the form; 16/17 ignore it.
        'type': 'password',
      },
    );

    if (posted.isRedirect) {
      final target = posted.location!;

      if (_isTotpUrl(target)) {
        _totpUrl = target;
        return const TotpHandshake._(TotpHandshakeOutcome.codeRequired);
      }

      // The account no longer needs a code at all — 2FA was turned off
      // between the failed RPC login and this screen — and the password
      // alone signed it in.
      final sessionId = _cookies[_sessionCookie];
      if (_isAuthenticatedLanding(target) &&
          sessionId != null &&
          sessionId.isNotEmpty) {
        return TotpHandshake._(
          TotpHandshakeOutcome.authenticated,
          sessionId: sessionId,
        );
      }

      // Anything else is a hand-off this client does not drive: an SSO
      // authorize endpoint, a custom post-login route. It goes to the
      // WebView rather than being guessed at.
      throw TotpHandshakeUnsupported(
        'the login posted through to ${target.path}',
      );
    }

    if (posted.statusCode == 200) {
      // Some deployments render the challenge in place of redirecting to it.
      if (_isTotpForm(posted.body)) {
        final inlineToken = _extractCsrfToken(posted.body);
        if (inlineToken != null) {
          _csrfToken = inlineToken;
          _totpUrl = _url('/web/login/totp');
          return const TotpHandshake._(TotpHandshakeOutcome.codeRequired);
        }
      }

      // Odoo re-renders the login form with the reason in an alert instead of
      // redirecting: a changed password, a disabled account, or the login
      // rate limiter.
      final error = _extractAlert(posted.body);
      if (error != null) {
        return TotpHandshake._(
          TotpHandshakeOutcome.credentialsRejected,
          message: error,
        );
      }
    }

    throw TotpHandshakeUnsupported(
      'the login answered HTTP ${posted.statusCode} unexpectedly',
    );
  }

  /// Runs step 3 with the six-digit [code], and on success returns the
  /// session id Odoo issued for the now fully authenticated session.
  ///
  /// [begin] must have returned [TotpHandshakeOutcome.codeRequired] first.
  Future<TotpSubmission> submitCode(String code) async {
    final totpUrl = _totpUrl;
    final csrfToken = _csrfToken;
    if (totpUrl == null || csrfToken == null) {
      throw StateError('submitCode() called before a successful begin()');
    }

    var response = await _postCode(totpUrl, csrfToken, code);

    if (response.statusCode == HttpStatus.badRequest) {
      // Odoo answers 400 "Session expired (invalid CSRF token)" when the
      // token no longer matches the session id. Re-read the token off the
      // form and resend — the same code is still good for the rest of its
      // 30-second window, so the user does not have to type a new one.
      final refreshed = await _refreshCsrfToken(totpUrl);
      if (refreshed == null) return const TotpSubmission.handshakeExpired();
      _csrfToken = refreshed;
      response = await _postCode(totpUrl, refreshed, code);
    }

    if (response.isRedirect) {
      final target = response.location!;

      // Back to the login form means the partial session is gone (expired,
      // or cleared server-side), not that the code was wrong. Bounced back to
      // the challenge itself means the code was refused.
      if (_isLoginUrl(target)) return const TotpSubmission.handshakeExpired();
      if (_isTotpUrl(target)) {
        return const TotpSubmission.codeRejected(
          'Invalid code or login failed. Please try again.',
        );
      }

      final sessionId = _cookies[_sessionCookie];
      if (sessionId == null || sessionId.isEmpty) {
        throw const TotpHandshakeUnsupported(
          'the server issued no session cookie after the code was accepted',
        );
      }
      return TotpSubmission.authenticated(sessionId);
    }

    if (response.statusCode == 200) {
      // The form comes back rendered with the reason — a wrong code, a
      // malformed one, or `auth_totp`'s rate limiter after repeated tries.
      if (_isTotpForm(response.body)) {
        return TotpSubmission.codeRejected(
          _extractAlert(response.body) ??
              'Invalid code. Please try again with a fresh code from your '
                  'authenticator app.',
        );
      }
    }

    throw TotpHandshakeUnsupported(
      'the code submission answered HTTP ${response.statusCode} unexpectedly',
    );
  }

  /// Releases the underlying connection. Safe to call more than once.
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }

  Future<_RawResponse> _postCode(Uri totpUrl, String csrfToken, String code) {
    return _send(
      'POST',
      totpUrl,
      form: {
        'csrf_token': csrfToken,
        'totp_token': code,
        // `remember` is deliberately left out. Setting it would have Odoo
        // issue a trusted-device cookie, and this app has no browser to keep
        // one in — it would only weaken the next sign-in on this server.
      },
    );
  }

  /// Re-reads the CSRF token off the TOTP form, or returns null when the
  /// partial session behind it is gone.
  Future<String?> _refreshCsrfToken(Uri totpUrl) async {
    final response = await _send('GET', totpUrl);
    // No `td_id` is ever sent (see [_cookies]), so this GET cannot finalize
    // the session on a device Odoo happens to trust — it can only re-render
    // the form or bounce back to the login page.
    if (response.isRedirect || response.statusCode != 200) return null;
    return _extractCsrfToken(response.body);
  }

  // ---------------------------------------------------------------------
  // HTTP plumbing
  // ---------------------------------------------------------------------

  /// Sends one request and reads the response without following redirects —
  /// which redirect Odoo answers with *is* the result at each step.
  Future<_RawResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? form,
  }) async {
    final request = await _client.openUrl(method, url);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.userAgentHeader, _userAgent)
      ..set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      )
      ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');

    if (_cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, _cookieHeader());
    }

    if (form != null) {
      final body = utf8.encode(_encodeForm(form));
      request.headers
        ..set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded',
        )
        ..set(HttpHeaders.contentLengthHeader, body.length.toString());
      request.add(body);
    }

    final response = await request.close().timeout(timeout);
    _absorbCookies(response);

    final location = _redirectTarget(response, url);
    if (location != null) {
      await response.drain<void>();
      return _RawResponse(
        statusCode: response.statusCode,
        uri: url,
        location: location,
        body: '',
      );
    }

    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(timeout);
    return _RawResponse(statusCode: response.statusCode, uri: url, body: body);
  }

  /// Like [_send], but chases redirects as a browser would. Used for the
  /// opening `GET /web/login?db=…`, which Odoo answers with a bounce to the
  /// same URL once it has attached the session cookie for that database.
  Future<_RawResponse> _follow(
    String method,
    Uri url, {
    Map<String, String>? form,
  }) async {
    var response = await _send(method, url, form: form);
    var hops = 0;
    while (response.isRedirect) {
      if (++hops > _maxRedirects) {
        throw const TotpHandshakeUnsupported('too many redirects');
      }
      response = await _send('GET', response.location!);
    }
    return response;
  }

  Uri? _redirectTarget(HttpClientResponse response, Uri from) {
    const redirects = {
      HttpStatus.movedPermanently,
      HttpStatus.found,
      HttpStatus.seeOther,
      HttpStatus.temporaryRedirect,
      HttpStatus.permanentRedirect,
    };
    if (!redirects.contains(response.statusCode)) return null;
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location == null || location.isEmpty) return null;
    return _rebase(from.resolve(location));
  }

  /// Parsed by hand rather than through [HttpClientResponse.cookies], whose
  /// parser rejects attribute spellings that proxies in front of Odoo do
  /// emit — and a throw there would lose the session cookie sitting in the
  /// same response.
  void _absorbCookies(HttpClientResponse response) {
    final headers = response.headers[HttpHeaders.setCookieHeader];
    if (headers == null) return;

    for (final header in headers) {
      final pair = header.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;

      final name = pair.substring(0, separator).trim();
      // Never kept: a trusted-device cookie in this jar would be offered back
      // to `/web/login/totp` and could skip the very check this screen
      // exists to perform.
      if (name == _trustedDeviceCookie) continue;

      var value = pair.substring(separator + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  String _cookieHeader() =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  static String _encodeForm(Map<String, String> form) => form.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  Uri _url(String path, [Map<String, String>? query]) {
    final url = _base.replace(path: _path(path));
    return query == null || query.isEmpty
        ? url
        : url.replace(queryParameters: query);
  }

  /// Keeps every hop on the origin the user actually signed in to, rather
  /// than on whatever host the redirect names.
  ///
  /// Odoo behind a reverse proxy routinely emits a `Location` pointing at its
  /// own internal hostname or at `http://` where the user reached it over
  /// `https://`. Following that verbatim would send the next request — and
  /// the session cookie with it — somewhere unreachable, and would leave this
  /// app holding a session issued for a host its RPC client never talks to.
  /// Only the path and query are taken from the redirect.
  Uri _rebase(Uri resolved) => _base.replace(
    path: _path(resolved.path),
    query: resolved.hasQuery ? resolved.query : null,
  );

  /// Re-applies the base URL's path prefix for deployments served under a
  /// sub-path, where Odoo still emits root-relative redirects.
  String _path(String path) {
    final prefix = _base.path;
    if (prefix.isEmpty || prefix == '/') return path;
    if (path == prefix || path.startsWith('$prefix/')) return path;
    return '$prefix$path';
  }

  bool _isTotpUrl(Uri url) => url.path.endsWith('/web/login/totp');

  bool _isLoginUrl(Uri url) =>
      url.path.endsWith('/web/login') || url.path.endsWith('/web/login/');

  bool _isDatabaseManagerUrl(Uri url) =>
      url.path.contains('/web/database/selector') ||
      url.path.contains('/web/database/manager');

  /// The three places `_get_login_redirect_url` sends a fully authenticated
  /// user when no explicit redirect was asked for: the web client on 16/17,
  /// on 18/19, and the portal landing page for a non-internal user.
  ///
  /// Checked as an allowlist rather than as "anything that isn't the login
  /// page", so a hand-off this client does not understand — an SSO
  /// authorize endpoint, a custom post-login route — goes to the WebView
  /// instead of being mistaken for a completed sign-in.
  bool _isAuthenticatedLanding(Uri url) {
    final path = url.path;
    return path == '/web' ||
        path == '/web/' ||
        path == '/odoo' ||
        path == '/odoo/' ||
        path.startsWith('/web/login_successful') ||
        _path('/web') == path ||
        _path('/odoo') == path;
  }

  /// The server URL as typed can carry a path prefix (Odoo behind a reverse
  /// proxy on a sub-path), which is kept and re-applied by [_path].
  static Uri _parseBase(String serverUrl) {
    var url = serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return Uri.parse(url);
  }

  // ---------------------------------------------------------------------
  // Response parsing
  // ---------------------------------------------------------------------

  static final RegExp _csrfFieldPattern = RegExp(
    r'''name=["']csrf_token["'][^>]*?value=["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _csrfFieldReversedPattern = RegExp(
    r'''value=["']([^"']+)["'][^>]*?name=["']csrf_token["']''',
    caseSensitive: false,
  );

  static final RegExp _alertPattern = RegExp(
    r'''<(p|div)[^>]*class=["'][^"']*alert-danger[^"']*["'][^>]*>(.*?)</\1>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _tagPattern = RegExp(r'<[^>]*>');
  static final RegExp _whitespacePattern = RegExp(r'\s+');

  static String? _extractCsrfToken(String html) =>
      _csrfFieldPattern.firstMatch(html)?.group(1) ??
      _csrfFieldReversedPattern.firstMatch(html)?.group(1);

  static bool _looksLikeOdooLoginForm(String html) =>
      html.contains('name="login"') && html.contains('name="password"');

  static bool _isTotpForm(String html) => html.contains('name="totp_token"');

  /// Pulls the message out of Odoo's `alert-danger` block and flattens it to
  /// one line, so the server's own wording is what the user reads.
  static String? _extractAlert(String html) {
    final match = _alertPattern.firstMatch(html);
    if (match == null) return null;

    final text = _unescapeHtml(match.group(2) ?? '')
        .replaceAll(_tagPattern, ' ')
        .replaceAll(_whitespacePattern, ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  static String _unescapeHtml(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  // ---------------------------------------------------------------------

  /// Asks Odoo what [sessionId] actually is, via `/web/session/get_session_info`.
  ///
  /// This is the only authoritative answer about a session: a cookie on its
  /// own says nothing about whether the second factor was ever verified.
  /// Returns null when the call fails or the server returns no result, which
  /// callers must treat as "not authenticated".
  static Future<Map<String, dynamic>?> fetchSessionInfo({
    required String serverUrl,
    required String sessionId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.postUrl(
        _parseBase(serverUrl).resolve('web/session/get_session_info'),
      );
      request.headers
        ..set(HttpHeaders.cookieHeader, '$_sessionCookie=$sessionId')
        ..set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}}),
      );

      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(timeout);

      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['result'] is! Map) return null;
      return Map<String, dynamic>.from(decoded['result'] as Map);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Signals that this server's login is not the standard Odoo
/// password-then-TOTP form pair this client drives — a themed template with
/// no CSRF field, an SSO hand-off, a redirect to another host. The caller
/// falls back to the WebView, which can drive whatever is actually served.
class TotpHandshakeUnsupported implements Exception {
  const TotpHandshakeUnsupported(this.reason);

  final String reason;

  @override
  String toString() => 'TotpHandshakeUnsupported: $reason';
}

/// What [OdooTotpHttpClient.begin] found once the password was accepted.
enum TotpHandshakeOutcome {
  /// Odoo holds a partial session and is waiting for the six-digit code.
  codeRequired,

  /// The server signed the user in outright — 2FA is no longer required for
  /// this account. No code is needed.
  authenticated,

  /// The login/password pair was refused.
  credentialsRejected,
}

class TotpHandshake {
  const TotpHandshake._(this.outcome, {this.sessionId, this.message});

  final TotpHandshakeOutcome outcome;

  /// Set only for [TotpHandshakeOutcome.authenticated].
  final String? sessionId;

  /// Odoo's own wording, set only for
  /// [TotpHandshakeOutcome.credentialsRejected].
  final String? message;
}

/// What came back from submitting a code.
enum TotpSubmitOutcome {
  /// The code was accepted; [TotpSubmission.sessionId] is the live session.
  authenticated,

  /// The server refused the code (wrong, expired, or rate limited).
  codeRejected,

  /// The partial session behind this attempt is gone, so the password step
  /// has to be replayed before the code can be sent again. Not a wrong code.
  handshakeExpired,
}

class TotpSubmission {
  const TotpSubmission._(this.outcome, {this.sessionId, this.message});

  const TotpSubmission.authenticated(String sessionId)
    : this._(TotpSubmitOutcome.authenticated, sessionId: sessionId);

  const TotpSubmission.codeRejected(String message)
    : this._(TotpSubmitOutcome.codeRejected, message: message);

  const TotpSubmission.handshakeExpired()
    : this._(TotpSubmitOutcome.handshakeExpired);

  final TotpSubmitOutcome outcome;

  /// Set only for [TotpSubmitOutcome.authenticated].
  final String? sessionId;

  /// Set only for [TotpSubmitOutcome.codeRejected].
  final String? message;
}

class _RawResponse {
  const _RawResponse({
    required this.statusCode,
    required this.uri,
    this.location,
    required this.body,
  });

  final int statusCode;

  /// The URL this response actually came from, which after [_follow] is the
  /// end of the redirect chain rather than where it started.
  final Uri uri;

  /// The resolved `Location`, or null when this was not a redirect.
  final Uri? location;

  /// Empty for redirects, which are never read.
  final String body;

  bool get isRedirect => location != null;
}
