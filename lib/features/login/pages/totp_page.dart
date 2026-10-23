import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/services/inventory_access_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/module_missing_dialog.dart';
import '../../../shared/widgets/dialogs/access_denied_dialog.dart';
import '../services/totp_http_login_service.dart';
import '../widgets/totp_webview_fallback.dart';
import 'login_layout.dart' show DatabaseExpiry;

/// TOTP (two-factor authentication) page: collects the six-digit code and
/// completes the Odoo login with it.
///
/// The login is driven by [OdooTotpHttpClient] as three ordinary form
/// requests. The first two — the ones that need only the password — are sent
/// the moment this page opens, while the user is still reaching for their
/// authenticator app, so by the time a code is typed only one round trip is
/// left.
///
/// [TotpWebViewFallback] takes over for servers whose login pages that client
/// does not recognise. On a standard Odoo server no WebView is ever created.
class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  /// True when this TOTP verification is part of adding a second account, or
  /// switching to a stored one, rather than a fresh sign-in. A
  /// module-missing/access-denied rejection then returns to the account that
  /// was already signed in instead of leaving the user on a dead-end page.
  final bool isAddingAccount;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
    this.isAddingAccount = false,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isButtonEnabled = false;

  /// Drives the login over plain HTTP. Null once the flow has handed off to
  /// [_webViewFallback].
  OdooTotpHttpClient? _httpClient;

  /// Only created for servers the HTTP client could not drive.
  TotpWebViewFallbackController? _webViewFallback;

  /// Completes when a code can be submitted. Awaited by [_submitTotp] so a
  /// user who types faster than the handshake still gets a single, seamless
  /// wait rather than a failed attempt.
  late Future<void> _preparation;

  /// Blocking overlay, fallback only — the HTTP handshake never shows one.
  bool _loading = false;

  /// True while a code is in flight, or while the session it produced is
  /// being verified and saved.
  bool _verifying = false;

  /// Set when the flow cannot continue as it stands (refused password,
  /// unreachable server). The next Authenticate tap starts it over.
  bool _blocked = false;

  /// A session the server issued without ever asking for a code, i.e.
  /// two-factor is no longer enabled for this account. Held rather than only
  /// acted on, so a code submitted in the same moment finishes with this
  /// session instead of being sent to a server that is no longer expecting
  /// one.
  String? _sessionWithoutCode;

  String? _error;

  @override
  void initState() {
    super.initState();
    _preparation = _prepare();
  }

  @override
  void dispose() {
    _httpClient?.close();
    _totpController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Login flow
  // ---------------------------------------------------------------------

  /// Sends the password half of the login — everything that does not need
  /// the user's code — so only the code submission is left by the time they
  /// have one. Never throws: every outcome is reported through the UI state.
  Future<void> _prepare() async {
    if (_webViewFallback != null) {
      // This server already turned out not to be one the HTTP client can
      // drive; replay the WebView rather than re-testing that.
      await _startWebViewFallback();
      return;
    }

    _httpClient?.close();
    final client = OdooTotpHttpClient(
      serverUrl: widget.serverUrl,
      database: widget.database,
    );
    _httpClient = client;

    TotpHandshake handshake;
    try {
      handshake = await client.begin(
        login: widget.username,
        password: widget.password,
      );
    } on TotpHandshakeUnsupported {
      // A login flow this client does not drive — hand over to the WebView,
      // which renders whatever the server actually serves.
      await _startWebViewFallback();
      return;
    } on SocketException {
      await _startWebViewFallback();
      return;
    } on HandshakeException {
      // A certificate Dart refuses but the WebView is configured to accept.
      await _startWebViewFallback();
      return;
    } on TimeoutException {
      _fail('The server took too long to respond. Please try again.');
      return;
    } catch (_) {
      await _startWebViewFallback();
      return;
    }

    if (!mounted) return;

    switch (handshake.outcome) {
      case TotpHandshakeOutcome.codeRequired:
        break;

      case TotpHandshakeOutcome.authenticated:
        // Two-factor is no longer switched on for this account, and the
        // password alone signed it in. [_signInWithoutCode] still verifies
        // the session with the server before it is kept.
        await _signInWithoutCode(handshake.sessionId!);

      case TotpHandshakeOutcome.credentialsRejected:
        _fail(
          handshake.message ??
              'Sign-in was refused. Please check your credentials and try '
                  'again.',
        );
    }
  }

  /// Signs in with a session the server issued without asking for a code,
  /// which happens only when two-factor is no longer enabled for this
  /// account.
  Future<void> _signInWithoutCode(String sessionId) async {
    _sessionWithoutCode = sessionId;
    // A submission already in flight picks this session up itself once it is
    // done waiting on the handshake, so this stays out of its way.
    if (_verifying || !mounted) return;
    setState(() => _verifying = true);
    try {
      await _completeLogin(sessionId);
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Mounts the WebView fallback and waits for it to reach the TOTP form.
  Future<void> _startWebViewFallback() async {
    if (!mounted) return;

    final fallback = TotpWebViewFallbackController();
    _httpClient?.close();
    setState(() {
      _httpClient = null;
      _webViewFallback = fallback;
      // The only path that still shows the overlay: driving the real login
      // pages means two full page loads before a code can be sent.
      _loading = true;
    });

    try {
      await fallback.ready;
    } catch (_) {
      _fail(
        'Could not reach the sign-in page on this server. Please check your '
        'connection and try again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submitTotp() async {
    if (_verifying) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() => _error = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      if (_blocked) {
        // The last attempt to reach the server failed outright. Start the
        // whole flow over rather than leaving this button dead.
        setState(() => _blocked = false);
        _preparation = _prepare();
      }

      // Normally already finished — the handshake ran while the code was
      // being read off the authenticator app.
      await _preparation;
      if (!await _readyToSendCode()) return;

      var submission = await _sendCode(totp);

      if (submission.outcome == TotpSubmitOutcome.handshakeExpired) {
        // The partial session aged out while this screen sat open. Replay
        // the password step and resend the same code, which is still inside
        // its own validity window.
        _preparation = _prepare();
        await _preparation;
        if (!await _readyToSendCode()) return;
        submission = await _sendCode(totp);
      }

      if (!mounted) return;

      switch (submission.outcome) {
        case TotpSubmitOutcome.authenticated:
          await _completeLogin(submission.sessionId!);

        case TotpSubmitOutcome.codeRejected:
          _showError(submission.message!);

        case TotpSubmitOutcome.handshakeExpired:
          _showError(
            'Your sign-in attempt expired. Please enter a fresh code.',
          );
      }
    } on TimeoutException {
      _showError('The server took too long to respond. Please try again.');
    } on SocketException {
      _showError(
        'Could not reach the server. Please check your connection and try '
        'again.',
      );
    } catch (_) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Whether the code still has anywhere to go once the handshake has
  /// settled. A handshake that came back already signed in finishes the
  /// login here instead — sending a code to a server that is no longer
  /// expecting one would only fail.
  Future<bool> _readyToSendCode() async {
    if (!mounted || _blocked) return false;

    final sessionWithoutCode = _sessionWithoutCode;
    if (sessionWithoutCode != null) {
      await _completeLogin(sessionWithoutCode);
      return false;
    }
    return true;
  }

  /// Submits [code] through whichever transport is driving this login,
  /// switching to the WebView fallback if the HTTP one turns out not to
  /// handle this server's TOTP form after all.
  Future<TotpSubmission> _sendCode(String code) async {
    final client = _httpClient;
    if (client != null) {
      try {
        return await client.submitCode(code);
      } on TotpHandshakeUnsupported {
        await _startWebViewFallback();
        if (!mounted || _blocked) {
          return const TotpSubmission.handshakeExpired();
        }
      }
    }

    final fallback = _webViewFallback;
    if (fallback == null) {
      throw StateError('no transport is driving this login');
    }
    await fallback.ready;
    return fallback.submit(code);
  }

  /// Verifies the session the server issued, keeps it, and lands the user in
  /// the app.
  Future<void> _completeLogin(String sessionId) async {
    // The only authoritative check: ask Odoo whether this session is
    // actually authenticated, and as the expected user. A cookie or a
    // redirect on its own can't tell a verified session apart from one that
    // skipped the challenge entirely.
    final sessionInfo = await OdooTotpHttpClient.fetchSessionInfo(
      serverUrl: widget.serverUrl,
      sessionId: sessionId,
    );

    final uid = sessionInfo?['uid'];
    final sessionLogin = (sessionInfo?['username'] ?? sessionInfo?['login'])
        ?.toString();
    final isVerified =
        uid is int &&
        uid > 0 &&
        (sessionLogin == null ||
            sessionLogin.toLowerCase() ==
                widget.username.trim().toLowerCase());

    if (!isVerified) {
      if (!mounted) return;
      if (_sessionWithoutCode == sessionId) {
        // Nothing for the user to retype: this session came from a server
        // that never asked for a code, so a fresh one would go nowhere.
        _sessionWithoutCode = null;
        _fail('Sign-in could not be completed. Please try again.');
      } else {
        _showError('Invalid code or login failed. Please try again.');
      }
      return;
    }

    final saved = await _saveSessionData(
      sessionId: sessionId,
      sessionInfo: sessionInfo!,
    );
    if (!mounted || !saved) return;

    // Data from a previously active account is cleared by
    // AccountChangeListener as soon as this session is committed.

    // `go`, not `pop`: this replaces the whole login stack underneath —
    // including this imperatively pushed page — with the app itself.
    context.goNamed(AppRoutes.app);
  }

  /// Persists the session established by the TOTP login, then gates it behind
  /// the same module/access checks every other login path in this app
  /// enforces. Returns true only when the session is kept; on a false return
  /// the caller must not navigate — a dialog (module missing/access denied)
  /// already tells the user what happened.
  Future<bool> _saveSessionData({
    required String sessionId,
    required Map<String, dynamic> sessionInfo,
  }) async {
    // An expired database is refused before anything else, and before this
    // session is established locally at all. [sessionInfo] is the server's
    // own `get_session_info` answer for it, so no extra request is needed.
    if (DatabaseExpiry.isExpiredSessionInfo(sessionInfo)) {
      if (!mounted) return false;
      setState(() => _error = null);
      DatabaseExpiry.showExpiredDialog(
        context,
        actionLabel: widget.isAddingAccount ? 'OK' : 'Back to Login',
        onClose: _leaveRejectedFlow,
      );
      return false;
    }

    // Snapshotted before this TOTP session is established: if the
    // module/access checks that follow reject it, this is what gets restored
    // so the active client is never left pointed at a rejected account.
    final previousSession = await OdooSessionManager.getCurrentSession();

    // Held in memory only until the checks below pass. Nothing about this
    // account — not the session, not its password — reaches the device
    // before this app has agreed it can be used.
    OdooSessionManager.beginProvisionalSession();

    final bool success;
    try {
      success = await OdooSessionManager.loginAndSaveSession(
        serverUrl: widget.serverUrl,
        database: widget.database,
        userLogin: widget.username.trim(),
        password: widget.password.trim(),
        sessionId: sessionId,
        serverVersion: sessionInfo['server_version']?.toString(),
      );
    } catch (_) {
      await OdooSessionManager.discardProvisionalSession(previousSession);
      rethrow;
    }

    if (!success) {
      await OdooSessionManager.discardProvisionalSession(previousSession);
      if (mounted) {
        setState(() {
          _error = 'Invalid code or login failed. Please try again.';
        });
      }
      return false;
    }

    // Module is checked first: a server missing Inventory is always reported
    // as that, rather than blamed on the user's own access rights. Portal
    // access is only checked once the module is confirmed present.
    final accessService = InventoryAccessService();

    final inventoryInstalled = await accessService.isInventoryModuleInstalled();
    if (!inventoryInstalled) {
      await OdooSessionManager.discardProvisionalSession(previousSession);
      if (!mounted) return false;
      showModuleMissingDialog(
        context,
        actionLabel: widget.isAddingAccount ? 'OK' : 'Back to Login',
        onClose: _leaveRejectedFlow,
      );
      return false;
    }

    final isPortal = await accessService.isPortalUser();
    if (isPortal) {
      await OdooSessionManager.discardProvisionalSession(previousSession);
      if (!mounted) return false;
      setState(() => _error = null);
      showAccessDeniedDialog(
        context,
        message: InventoryAccessService.portalUserMessage,
        onClose: _leaveRejectedFlow,
      );
      return false;
    }

    // Cleared every check — write the session through and register the
    // account so it appears in the account switcher. Registering earlier
    // listed an account that a failed check then rolled the session back
    // from, leaving the switcher and the session manager disagreeing about
    // which account this app is signed in to.
    await OdooSessionManager.commitProvisionalSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logoutAction');
    await prefs.setString('sessionId', sessionId);
    await prefs.setString('username', widget.username);
    await prefs.setString('url', widget.serverUrl);
    await prefs.setString('database', widget.database);
    await prefs.setBool('logoutAction', false);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

    try {
      final currentSession = await OdooSessionManager.getCurrentSession();
      if (currentSession != null) {
        await SessionService.instance.storeAccount(
          currentSession,
          widget.password.trim(),
          markAsCurrent: true,
        );
        if (widget.isAddingAccount) {
          await SessionService.instance.switchToAccount(currentSession);
        }
      }
    } catch (_) {}

    return true;
  }

  /// Where a rejected account leaves the user once they close the dialog.
  ///
  /// An add-account/switch flow returns to the account that was already
  /// signed in — it was restored by [discardProvisionalSession] above. A
  /// fresh sign-in has no account to go back to, so it goes to the login
  /// flow, which is what the dialog's own "Back to Login" button says.
  void _leaveRejectedFlow() {
    if (!mounted) return;
    context.goNamed(
      widget.isAddingAccount ? AppRoutes.app : AppRoutes.serverSetup,
    );
  }

  // ---------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  /// A failure no retyped code can get past on its own. Lifts any overlay so
  /// the screen shows [message]; the next Authenticate tap starts the whole
  /// flow over.
  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _blocked = true;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/images/loginbg.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(1)
                          : Colors.white.withOpacity(1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_webViewFallback != null)
            TotpWebViewFallback(
              // Keyed on the controller so restarting the fallback builds a
              // fresh WebView bound to the new controller, rather than
              // leaving the old State attached to the old one.
              key: ObjectKey(_webViewFallback),
              controller: _webViewFallback!,
              serverUrl: widget.serverUrl,
              database: widget.database,
              username: widget.username,
              password: widget.password,
              onAuthenticated: _signInWithoutCode,
            ),

          // The Scaffold doesn't resize for the keyboard (so the background
          // stays put), so the form's viewport is lifted above the keyboard
          // here instead. Without it the code field sat behind the keyboard
          // while typing, and the form overflowed in landscape.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 48).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 20),
                                _buildForm(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _loading,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: _loading ? Colors.white54 : Colors.white,
                        size: 24.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).colorScheme.primary,
                  size: 60,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // A phone in landscape: tighter so the code field and button fit
    // without scrolling past the header first.
    final compact = MediaQuery.sizeOf(context).height < 500;

    return Column(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: compact ? 32 : 48,
        ),
        SizedBox(height: compact ? 12 : 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: compact ? 20 : 25,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading && !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withValues(alpha: 0.4),
              ),
              prefixIcon: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Transform.scale(
                    scale: 20 / 24.0,
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSmsCode,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                ),
              ),
              prefixIconColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    )
                  : Text(
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

}
