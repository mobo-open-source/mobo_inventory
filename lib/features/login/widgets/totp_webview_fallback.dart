import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/totp_http_login_service.dart';

/// Completes Odoo's two-factor login by driving the real login pages in an
/// offscreen WebView.
///
/// This is the fallback for servers [OdooTotpHttpClient] does not recognise —
/// a themed login template, a proxy that answers the form requests
/// differently, a certificate the Dart HTTP client refuses. It is slower
/// (every step is a full page load) but it can drive whatever the server
/// actually serves, so it is what keeps such servers working.
///
/// It is only ever built after the HTTP handshake has failed; on a standard
/// Odoo server no WebView is created at all.
class TotpWebViewFallback extends StatefulWidget {
  const TotpWebViewFallback({
    super.key,
    required this.controller,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.onAuthenticated,
  });

  /// The handle the OTP screen submits codes through.
  final TotpWebViewFallbackController controller;

  /// Called with the session id when the server signs the user in without
  /// ever asking for a code — two-factor turned off for this account between
  /// the failed RPC login and this screen. There is nothing to submit in
  /// that case, so the screen is told directly.
  final void Function(String sessionId) onAuthenticated;

  final String serverUrl;
  final String database;
  final String username;
  final String password;

  @override
  State<TotpWebViewFallback> createState() => _TotpWebViewFallbackState();
}

/// The OTP screen's handle on a [TotpWebViewFallback].
class TotpWebViewFallbackController {
  final Completer<void> _ready = Completer<void>();
  _TotpWebViewFallbackState? _state;

  /// Completes once the WebView has driven the login as far as the TOTP
  /// form, or completes with an error when it could not get there.
  Future<void> get ready => _ready.future;

  /// Submits [code] to the TOTP form. Await [ready] first.
  Future<TotpSubmission> submit(String code) {
    final state = _state;
    if (state == null) {
      throw StateError('submit() called before the fallback WebView mounted');
    }
    return state._submit(code);
  }

  void _attach(_TotpWebViewFallbackState state) => _state = state;

  void _detach(_TotpWebViewFallbackState state) {
    if (identical(_state, state)) _state = null;
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void _markFailed(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
  }
}

class _TotpWebViewFallbackState extends State<TotpWebViewFallback> {
  InAppWebViewController? _webController;
  bool _credentialsInjected = false;

  /// Bumped on every completed page load, so [_submit] can tell the form it
  /// posted from the page that came back, instead of sleeping and hoping.
  int _loadCount = 0;

  /// While true, [_submit] owns the outcome of the page loads coming in and
  /// [_onPageLoaded] leaves them alone.
  bool _submitting = false;

  /// [TotpWebViewFallback.onAuthenticated] is a one-shot: the web client
  /// loads several pages after a sign-in, and the screen only wants the
  /// first.
  bool _reportedAuthenticated = false;

  /// The WebView is only created once any cookies left for this server are
  /// cleared, so a device Odoo already trusts (or a leftover session) cannot
  /// skip the TOTP challenge and be mistaken for a code that was verified.
  bool _cookiesCleared = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _clearCookies();
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _webController?.dispose();
    super.dispose();
  }

  Future<void> _clearCookies() async {
    try {
      await CookieManager.instance().deleteCookies(
        url: WebUri(widget.serverUrl),
      );
    } catch (_) {
      // Not fatal: the session is verified against the server by the OTP
      // screen once this flow finishes, so cookies that couldn't be cleared
      // cannot turn into a false pass on their own.
    }
    if (!mounted) return;
    setState(() => _cookiesCleared = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_cookiesCleared) return const SizedBox.shrink();

    // Kept offscreen rather than hidden with opacity: a zero-opacity
    // full-screen WebView still sits over the form and swallows taps.
    return SizedBox(
      width: 0,
      height: 0,
      child: Offstage(
        child: SizedBox(
          width: 400,
          height: 800,
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('${widget.serverUrl}/web/login?db=${widget.database}'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              cacheEnabled: false,
              clearCache: true,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
              useHybridComposition: true,
              allowContentAccess: true,
              allowFileAccess: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              disableDefaultErrorPage: true,
            ),
            onWebViewCreated: (controller) => _webController = controller,
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            onReceivedError: (controller, request, error) {
              // Only the page itself: a failed image or stylesheet says
              // nothing about whether the login can be completed.
              if (request.isForMainFrame != true) return;
              widget.controller._markFailed(
                TotpHandshakeUnsupported(
                  'the login page could not be loaded (${error.description})',
                ),
              );
            },
            onLoadStop: (controller, url) async {
              _loadCount++;
              await _onPageLoaded(url);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onPageLoaded(WebUri? url) async {
    // A submission in flight reads these loads itself, and a second reader
    // racing it would fight over the same page.
    if (_submitting) return;

    final path = url?.path ?? '';
    final query = url?.queryParameters ?? const <String, String>{};

    if (path.startsWith('/web/database/selector') ||
        path.startsWith('/web/database/manager')) {
      await _selectDatabase();
      return;
    }

    if (path.startsWith('/web/login/totp') || query.containsKey('totp_token')) {
      widget.controller._markReady();
      return;
    }

    if (path.startsWith('/web/login')) {
      if (!_credentialsInjected) await _injectCredentials();
      return;
    }

    // Landed on the web client without the code ever being asked for, which
    // means the password alone was enough. Report the session rather than
    // leaving the screen waiting for a form that will never appear.
    if (url != null && path.isNotEmpty && !_reportedAuthenticated) {
      final sessionId = await _readSessionCookie(url);
      if (sessionId != null && sessionId.isNotEmpty) {
        _reportedAuthenticated = true;
        widget.controller._markReady();
        widget.onAuthenticated(sessionId);
      }
    }
  }

  Future<void> _injectCredentials() async {
    final safeUser = jsonEncode(widget.username);
    final safePass = jsonEncode(widget.password);
    final safeDb = jsonEncode(widget.database);

    final result = await _webController?.evaluateJavascript(
      source:
          """
      (function() {
        const login = document.querySelector('input[name="login"], input[type="email"]');
        const password = document.querySelector('input[name="password"]');
        const db = document.querySelector('input[name="db"], select[name="db"]');
        const form = document.querySelector('form[action*="/web/login"]');

        if (!login || !password || !form) return "missing";

        login.value = $safeUser;
        password.value = $safePass;
        if (db) db.value = $safeDb;

        const btn = form.querySelector('button[type="submit"]');
        if (btn) btn.click();
        else form.requestSubmit();

        return "submitted";
      })();
    """,
    );

    if (result == 'submitted') {
      _credentialsInjected = true;
    } else {
      widget.controller._markFailed(
        const TotpHandshakeUnsupported(
          'no login form was found on the page the server served',
        ),
      );
    }
  }

  Future<void> _selectDatabase() async {
    final safeDb = jsonEncode(widget.database);
    await _webController?.evaluateJavascript(
      source:
          """
      (function() {
        const select = document.querySelector('select[name="db"]');
        if (!select) return;
        select.value = $safeDb;
        const btn = document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      })();
    """,
    );
  }

  /// Fills the code into the real form, submits it, and waits for the page
  /// that comes back rather than for a fixed delay.
  Future<TotpSubmission> _submit(String code) async {
    final controller = _webController;
    if (controller == null) {
      throw const TotpHandshakeUnsupported('the fallback WebView is not ready');
    }

    _submitting = true;
    try {
      return await _submitAndWait(controller, code);
    } finally {
      _submitting = false;
    }
  }

  Future<TotpSubmission> _submitAndWait(
    InAppWebViewController controller,
    String code,
  ) async {
    final loadsBefore = _loadCount;
    final submitted = await controller.evaluateJavascript(
      source:
          """
      (function() {
        const input = document.querySelector(
          'input[name="totp_token"], input[autocomplete="one-time-code"]'
        );
        if (!input) return "missing";

        input.focus();
        input.value = ${jsonEncode(code)};
        input.dispatchEvent(new Event('input', {bubbles: true}));
        input.dispatchEvent(new Event('change', {bubbles: true}));

        const form = input.closest('form') || document.querySelector('form[method="POST"]');
        if (!form) return "missing";

        const btn = form.querySelector('button[type="submit"], button.btn-primary');
        if (btn) btn.click();
        else form.submit();

        return "submitted";
      })();
    """,
    );

    if (submitted != 'submitted') {
      throw const TotpHandshakeUnsupported(
        'no two-factor form was found on the page the server served',
      );
    }

    // 200ms × 75 ≈ 15s, which covers a slow server round trip plus the
    // web client's own load without leaving the user waiting indefinitely.
    for (var attempt = 0; attempt < 75; attempt++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) {
        throw const TotpHandshakeUnsupported('the two-factor screen closed');
      }
      if (_loadCount == loadsBefore) continue;

      final url = await controller.getUrl();
      final path = url?.path ?? '';

      if (path.startsWith('/web/login/totp')) {
        final error = await _readFormError();
        if (error != null) return TotpSubmission.codeRejected(error);
        continue;
      }

      // Bounced back to the password form: the partial session is gone, not
      // a wrong code.
      if (path.startsWith('/web/login')) {
        return const TotpSubmission.handshakeExpired();
      }

      if (url != null && path.isNotEmpty) {
        final sessionId = await _readSessionCookie(url);
        if (sessionId != null && sessionId.isNotEmpty) {
          return TotpSubmission.authenticated(sessionId);
        }
      }
    }

    return const TotpSubmission.codeRejected(
      'The server did not answer in time. Please try again with a fresh code.',
    );
  }

  /// Odoo's own wording for a refused code, read off the re-rendered form.
  Future<String?> _readFormError() async {
    final message = await _webController?.evaluateJavascript(
      source: """
      (function() {
        const alert = document.querySelector('.alert-danger');
        return alert ? alert.textContent.trim().replace(/\\s+/g, ' ') : null;
      })();
    """,
    );
    final text = message?.toString().trim();
    return (text == null || text.isEmpty || text == 'null') ? null : text;
  }

  Future<String?> _readSessionCookie(WebUri url) async {
    final cookies = await CookieManager.instance().getCookies(url: url);
    for (final cookie in cookies) {
      if (cookie.name == 'session_id') return cookie.value.toString();
    }
    return null;
  }
}
