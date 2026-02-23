import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';

/// Screen for handling Two-Factor Authentication (TOTP) during login.
/// Uses an [InAppWebView] to process the Odoo TOTP flow if necessary.
class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  InAppWebViewController? _webController;
  final _totpController = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _verifying = false;
  bool _isButtonEnabled = false;
  final _formKey = GlobalKey<FormState>();
  bool _credentialsInjected = false;
  String? sessionId;
  bool _isSessionExtracted = false;
  bool _loginSuccess = false;

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
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
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

          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    '${widget.serverUrl}/web/login?db=${widget.database}',
                  ),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  cacheEnabled: false,
                  clearCache: true,
                  userAgent:
                      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
                  useHybridComposition: true,
                  allowContentAccess: true,
                  allowFileAccess: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  forceDark: ForceDark.AUTO,
                  disableDefaultErrorPage: true,
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) async {
                  final urlStr = url?.toString() ?? '';

                  if (urlStr.contains('/web/database/selector') ||
                      urlStr.contains('/web/database/manager')) {
                    await _handleDatabaseSelector();
                    return;
                  }

                  if (urlStr.contains('/web/login') && !_credentialsInjected) {
                    await Future.delayed(const Duration(milliseconds: 800));
                    await _injectCredentials();
                    return;
                  }

                  if (urlStr.contains('/web/login/totp') ||
                      urlStr.contains('totp_token')) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 600));
                    await _focusTotpField();
                    return;
                  }

                  if ((urlStr.contains('/web') ||
                          urlStr.contains('/odoo/discuss') ||
                          urlStr.contains('/odoo') ||
                          urlStr.contains('/odoo/apps') ||
                          urlStr.contains('/website')) &&
                      !urlStr.contains('/login') &&
                      !urlStr.contains('/totp')) {
                    final sessionInfo = await controller.evaluateJavascript(
                      source: """
                        (function () {
                          return odoo && odoo.session_info ? odoo.session_info : null;
                        })();
                      """,
                    );
                    if (sessionInfo != null && !_isSessionExtracted) {
                      final success = await _saveSessionData(
                        sessionInfo: sessionInfo,
                      );
                      if (success) {
                        await _onLoginSuccess();
                      }
                    }
                  }
                },
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
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildForm(),
              ],
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

  Future<void> _submitTotp() async {
    if (_verifying || _webController == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final totp = _totpController.text.trim();
    if (totp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = 'Please enter a valid 6-digit code';
        _verifying = false;
      });
      return;
    }

    try {
      await _webController!.evaluateJavascript(
        source:
            """
  (function() {
    let input = document.querySelector(
      'input[name="totp_token"], input[autocomplete="one-time-code"], input[type="text"][maxlength="6"], input[type="number"][maxlength="6"]'
    );
    if (!input) return "totp_input_not_found";
    

    input.focus();
    input.value = '$totp';
    ['input', 'change', 'keydown', 'keyup', 'keypress'].forEach(eventType => {
      input.dispatchEvent(new KeyboardEvent(eventType, {key: 'Enter', bubbles: true, cancelable: true}));
    });
    

    const trustCheckbox = document.querySelector('input[name="trust_device"], input[type="checkbox"], [name="trust"]');
    if (trustCheckbox && !trustCheckbox.checked) {
      trustCheckbox.checked = true;
      trustCheckbox.dispatchEvent(new Event('change', {bubbles: true}));
    }
    

    const form = input.closest('form') || document.querySelector('form[action*="/web/login"]');
    if (form) {
      const btn = form.querySelector('button[type="submit"], button.btn-primary, button[name="submit"], button.btn-block');
      if (btn) {
        btn.click();
      } else {
        form.submit();  // Fallback to native submit
      }
      return "totp_submitted";
    }
    return "form_not_found";
    
  })();
  """,
      );

      await Future.delayed(const Duration(seconds: 2));

      for (int i = 0; i < 20; i++) {
        final isLoggedIn = await _webController!.evaluateJavascript(
          source: """
    (function() {
      const userMenu = document.querySelector('.o_user_menu, .oe_topbar_avatar, .o_apps_switcher, [data-menu="account"]');
      const webClient = document.querySelector('.o_web_client, .o_action_manager');
      const error = document.querySelector('.alert-danger, .o_error_dialog');
      if (userMenu || webClient) return true;
      if (error) return 'error';
      return false;
    })();
    """,
        );
        if (isLoggedIn == 'error') {
          setState(
            () => _error = "Invalid code or login failed. Please try again.",
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await Future.delayed(const Duration(seconds: 4));

      final currentUrl = await _webController!.getUrl();
      final urlStr = currentUrl?.toString() ?? '';

      final cookies = await CookieManager.instance().getCookies(
        url: currentUrl!,
      );

      final sessionCookie = cookies.firstWhere(
        (c) => c.name == 'session_id',
        orElse: () => Cookie(name: '', value: ''),
      );

      if (sessionCookie.value.isEmpty) {
        setState(() => _error = "Login failed or invalid TOTP.");
        return;
      }

      final domSuccess = await _webController!.evaluateJavascript(
        source: """
      (function() {
        const hasUserMenu = !!document.querySelector('.o_user_menu, .oe_topbar_avatar');
        const hasWebClient = !!document.querySelector('.o_web_client');
        return hasUserMenu || hasWebClient;
      })();
    """,
      );

      if (domSuccess == true ||
          currentUrl.toString().contains('/web?') ||
          currentUrl.toString().contains('/odoo/discuss?') ||
          currentUrl.toString().contains('/odoo') ||
          currentUrl.toString().contains('/odoo/apps?')) {
        if (!_isSessionExtracted) {
          await _saveSessionData();
        }
      }

      final isSuccess =
          sessionCookie.value.isNotEmpty &&
          sessionCookie.value.length > 20 &&
          ((urlStr.contains('/web') ||
                  (urlStr.contains('/odoo/discuss')) ||
                  (urlStr.contains('/odoo')) ||
                  (urlStr.contains('/odoo/apps'))) &&
              !urlStr.contains('/login') &&
              !urlStr.contains('/totp'));

      if (!isSuccess && !_isSessionExtracted) {
        if (mounted) {
          setState(() {
            _error = 'Invalid code or login failed. Please try again.';
          });
        }
        return;
      }

      if (mounted && _isSessionExtracted) {
        await _onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Authentication failed. Please try again.';
        });
      }
    } finally {
      if (mounted && !_loginSuccess) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _onLoginSuccess() async {
    if (!mounted) return;

    setState(() {
      _loginSuccess = true;
      _verifying = true;
    });

    final client = await OdooSessionManager.getClient();

    if (client != null) {
      try {
        final modules = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'ir.module.module',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'domain': [
              [
                'name',
                'in',
                ['stock'],
              ],
              ['state', '=', 'installed'],
            ],
            'fields': ['name', 'state'],
          },
        });

        final isInstalled = modules != null && modules.isNotEmpty;

        if (!isInstalled) {
          await OdooSessionManager.logout();
          if (mounted) {
            setState(() {
              _loginSuccess = false;
              _verifying = false;
            });
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Required modules are missing on this server.'),
              ),
            );
          }
          return;
        }
      } catch (e) {}
    }

    if (!mounted) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      context.goNamed(AppRoutes.app);
    }
  }

  Future<void> _saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  Future<bool> _saveSessionData({Map<String, dynamic>? sessionInfo}) async {
    if (_isSessionExtracted) return true;

    try {
      final currentUrl = await _webController?.getUrl();
      final cookies = await CookieManager.instance().getCookies(
        url: currentUrl ?? WebUri(widget.serverUrl),
      );

      final sessionCookie = cookies.firstWhere(
        (cookie) => cookie.name == 'session_id',
        orElse: () => Cookie(name: '', value: ''),
      );

      if (sessionCookie.value.isNotEmpty) {
        sessionId = sessionCookie.value;

        final success = await OdooSessionManager.loginAndSaveSession(
          serverUrl: widget.serverUrl,
          database: widget.database,
          userLogin: widget.username.trim(),
          password: widget.password.trim(),
          sessionId: sessionId,
          serverVersion: sessionInfo?['server_version']?.toString(),
        );

        if (success) {
          await _saveUrlHistory(
            protocol: widget.protocol,
            url: widget.serverUrl,
            database: widget.database,
            username: widget.username.trim(),
          );

          try {
            final sessionService = SessionService.instance;
            final currentSession = await OdooSessionManager.getCurrentSession();

            if (currentSession != null) {
              await sessionService.storeAccount(
                currentSession,
                widget.password.trim(),
              );
            }
          } catch (e) {}

          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('logoutAction');
          await prefs.setString('sessionId', sessionId!);
          await prefs.setString('username', widget.username);
          await prefs.setString('url', widget.serverUrl);
          await prefs.setString('database', widget.database);
          await prefs.setBool('logoutAction', false);
          await prefs.setBool('isLoggedIn', true);
          await prefs.setInt(
            'loginTimestamp',
            DateTime.now().millisecondsSinceEpoch,
          );

          _isSessionExtracted = true;
          return true;
        } else {
          if (mounted && !_verifying) {
            setState(() {
              _error = 'Invalid code or login failed. Please try again.';
            });
          }
          return false;
        }
      } else {
        if (mounted && !_verifying) {
          setState(() {
            _error = 'Invalid code or login failed. Please try again.';
          });
        }
        return false;
      }
    } catch (e) {
      if (mounted && !_verifying) {
        setState(() {
          _error = 'Invalid code or login failed. Please try again.';
        });
      }
      return false;
    }
  }

  Future<void> _injectCredentials() async {
    if (_credentialsInjected) return;

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
        if (db) {
          if (db.tagName === 'INPUT') db.value = $safeDb;
          else db.value = $safeDb;
        }

        const btn = form.querySelector('button[type="submit"]');
        if (btn) btn.click();
        else form.requestSubmit();

        return "submitted";
      })();
    """,
    );

    if (result == "submitted") {
      _credentialsInjected = true;
    }
  }

  Future<void> _focusTotpField() async {
    await _webController?.evaluateJavascript(
      source: """
     (function() {
      const input = document.querySelector('input[name="totp_token"], input[autocomplete="one-time-code"]');
      if (input) {
        input.focus();
        input.select();
      }
     })();
    """,
    );
  }

  Future<void> _handleDatabaseSelector() async {
    await _webController?.evaluateJavascript(
      source:
          """
     (function() {
      const select = document.querySelector('select[name="db"]');
      if (select) {
        select.value = '${widget.database}';
        const btn = document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      }
     })();
    """,
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48.0,
        ),
        const SizedBox(height: 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSmsCode,
                size: 20.0,
                color: Colors.black54,
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
                          size: 18.0,
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
                        const Text('Verifying'),
                        const SizedBox(width: 12),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    )
                  : const Text(
                      'Verify & Login',
                      style: TextStyle(
                        fontSize: 16,
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
