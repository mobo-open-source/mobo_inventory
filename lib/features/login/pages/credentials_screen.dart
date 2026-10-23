import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import 'login_layout.dart';
import '../../../core/models/appsession.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/inventory_access_service.dart';
import '../../../core/services/biometric_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/exceptions/odoo_error_mapper.dart';
import '../../../core/utils/module_missing_dialog.dart';
import '../../../shared/widgets/dialogs/access_denied_dialog.dart';
import 'totp_page.dart';

/// Screen for entering user credentials (Email/Password) for authentication.
class CredentialsScreen extends StatefulWidget {
  final String url;
  final String database;
  final bool isAddingAccount;
  final String? prefilledUsername;
  final LoginProvider? provider;

  const CredentialsScreen({
    super.key,
    required this.url,
    required this.database,
    this.isAddingAccount = false,
    this.prefilledUsername,
    this.provider,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late LoginProvider _provider;

  bool _shouldValidate = false;

  bool emailHasError = false;
  bool passwordHasError = false;

  String? inlineError;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? LoginProvider();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.urlController.text = widget.url;
      _provider.setDatabase(widget.database);

      if (widget.prefilledUsername != null &&
          widget.prefilledUsername!.isNotEmpty) {
        _provider.emailController.text = widget.prefilledUsername!;
      }

      if (mounted) {
        if (_provider.emailController.text.isEmpty) {
          FocusScope.of(context).requestFocus(_emailFocus);
        } else {
          FocusScope.of(context).requestFocus(_passwordFocus);
        }
      }
    });
  }

  /// Abandons the whole Add Account flow and returns to the configuration
  /// screen it was launched from.
  ///
  /// That flow is Profile → server setup → this screen, so both of those are
  /// popped: neither a server without the module nor an account this app
  /// refuses can be completed from here. Guarded with canPop() so a
  /// shallower-than-expected stack stops instead of popping past the root.
  void _returnToConfiguration() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    for (var i = 0; i < 2 && router.canPop(); i++) {
      router.pop();
    }
  }

  Future<void> _handleSubmit(LoginProvider provider) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _shouldValidate = true;
    });
    final formValid = provider.formKey.currentState?.validate() ?? false;
    setState(() {
      emailHasError = provider.emailController.text.isEmpty;
      final pwd = provider.passwordController.text;
      passwordHasError = pwd.isEmpty || pwd.isEmpty;
      inlineError = null;
    });

    if (!formValid) {
      await HapticsService.warning();
      return;
    }

    if (widget.isAddingAccount) {
      bool success = false;
      try {
        success = await _addNewAccount(provider);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('two-factor') ||
            msg.contains('two factor') ||
            msg.contains('2fa') ||
            msg.contains('totp') ||
            msg.contains('token_expired') ||
            (msg.contains('null') && msg.contains('subtype'))) {
          if (!mounted) return;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: provider.getFullUrl(),
                database: widget.database,
                username: provider.emailController.text.trim(),
                password: provider.passwordController.text,
                protocol: provider.selectedProtocol,
                isAddingAccount: true,
              ),
            ),
          );
          if (result == true) {
            success = true;
          }
        }
      }

      if (!mounted) return;
      if (success) {
        HapticsService.success();

        setState(() {
          inlineError = null;
        });
        if (mounted) {
          context.goNamed(AppRoutes.app);
        }
      } else if (provider.databaseExpired) {
        setState(() {
          inlineError = null;
          provider.errorMessage = null;
        });
        DatabaseExpiry.showExpiredDialog(
          context,
          onClose: _returnToConfiguration,
        );
      } else if (provider.moduleMissing) {
        setState(() {
          inlineError = null;
          provider.errorMessage = null;
        });
        showModuleMissingDialog(
          context,
          actionLabel: 'OK',
          onClose: _returnToConfiguration,
        );
      } else if (provider.accessDenied) {
        final message =
            provider.errorMessage ?? InventoryAccessService.portalUserMessage;
        setState(() {
          inlineError = null;
          provider.errorMessage = null;
        });
        showAccessDeniedDialog(
          context,
          message: message,
          onClose: _returnToConfiguration,
        );
      } else {
        HapticsService.error();
        if (!mounted) return;
        setState(() {
          inlineError = provider.errorMessage ?? 'Failed to add account';
        });
      }
    } else {
      final biometricContext = BiometricContextService();
      biometricContext.startAccountOperation('login');

      bool ok = false;
      try {
        ok = await provider.login(context);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('two-factor') ||
            msg.contains('two factor') ||
            msg.contains('2fa') ||
            msg.contains('totp') ||
            msg.contains('token_expired') ||
            (msg.contains('null') && msg.contains('subtype'))) {
          if (!mounted) return;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: provider.getFullUrl(),
                database: widget.database,
                username: provider.emailController.text.trim(),
                password: provider.passwordController.text,
                protocol: provider.selectedProtocol,
              ),
            ),
          );
          if (result == true) {
            ok = true;
          }
        }
      }

      if (!mounted) return;
      if (ok) {
        HapticsService.success();
        setState(() {
          inlineError = null;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        TextInput.finishAutofillContext(shouldSave: true);
        context.goNamed(AppRoutes.app);
      } else if (provider.databaseExpired) {
        setState(() => inlineError = null);
        DatabaseExpiry.showExpiredDialog(context);
      } else if (provider.moduleMissing) {
        setState(() => inlineError = null);
        showModuleMissingDialog(context);
      } else if (provider.accessDenied) {
        final message =
            provider.errorMessage ?? InventoryAccessService.portalUserMessage;
        setState(() => inlineError = null);
        showAccessDeniedDialog(context, message: message);
      }
    }
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<bool> _addNewAccount(LoginProvider provider) async {
    try {
      provider.setLoading(true);
      provider.moduleMissing = false;
      provider.accessDenied = false;
      provider.databaseExpired = false;
      final biometricContext = BiometricContextService();
      biometricContext.startAccountOperation('add_account');

      final sessionService = SessionService.instance;
      final current = sessionService.currentSession;
      String serverUrl = widget.url.isNotEmpty
          ? widget.url
          : (current?.serverUrl ?? '');
      String database = widget.database.isNotEmpty
          ? widget.database
          : (current?.database ?? '');

      serverUrl = _ensureScheme(serverUrl);

      if (serverUrl.isEmpty || database.isEmpty) {
        provider.errorMessage =
            'Server URL or Database is missing. Please go back and try again.';
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      // Nothing this account touches is written to the device until it has
      // passed every check below — an account this app refuses must not be
      // left saved anywhere, and the probes themselves would otherwise
      // persist it on their way through the session manager.
      OdooSessionManager.beginProvisionalSession();

      final AppSessionData? newSession;
      try {
        newSession = await OdooSessionManager.authenticate(
          serverUrl: serverUrl,
          database: database,
          username: provider.emailController.text.trim(),
          password: provider.passwordController.text,
        );
      } catch (_) {
        await OdooSessionManager.discardProvisionalSession(current);
        rethrow;
      }

      if (newSession == null) {
        await OdooSessionManager.discardProvisionalSession(current);
        provider.errorMessage =
            'Authentication failed. Please check your credentials.';
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      // An expired database is refused before anything else: none of it is
      // usable, whatever modules or access rights it has.
      if (await DatabaseExpiry.isCurrentSessionExpired()) {
        await OdooSessionManager.discardProvisionalSession(current);
        provider.databaseExpired = true;
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      // Module is checked first: a server missing Inventory is always
      // reported as that, rather than blamed on the user's own access
      // rights. Portal access is only checked once the module is confirmed
      // present.
      final accessService = InventoryAccessService();
      final inventoryInstalled = await accessService
          .isInventoryModuleInstalled();
      if (!inventoryInstalled) {
        await OdooSessionManager.discardProvisionalSession(current);
        provider.moduleMissing = true;
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      final isPortal = await accessService.isPortalUser();
      if (isPortal) {
        await OdooSessionManager.discardProvisionalSession(current);
        provider.accessDenied = true;
        provider.errorMessage = InventoryAccessService.portalUserMessage;
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      // Cleared every check — this account may now be written to the device.
      await OdooSessionManager.commitProvisionalSession();

      // Pin the new account's own company scope before it is stored or made
      // current. `authenticate` leaves the company fields empty, so without
      // this the account's RPCs would be scoped by whatever company context
      // the previously active account left behind — a company it may not
      // even belong to.
      await OdooSessionManager.getClientEnsured();
      await OdooSessionManager.getAllowedCompaniesList();

      final fixedSession = newSession.copyWith(
        selectedCompanyId: newSession.companyId,
        allowedCompanyIds: newSession.allowedCompanyIds,
      );
      await fixedSession.saveToPrefs();
      await OdooSessionManager.updateSession(fixedSession);
      sessionService.updateSession(fixedSession);

      await sessionService.storeAccount(
        fixedSession,
        provider.passwordController.text,
        markAsCurrent: true,
      );

      // The previous account's data is cleared by AccountChangeListener as
      // soon as this account becomes current.

      try {
        final prefs = await SharedPreferences.getInstance();

        List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
        if (!urls.contains(serverUrl)) {
          urls.insert(0, serverUrl);
          if (urls.length > 10) {
            urls = urls.take(10).toList();
          }
          await prefs.setStringList('previous_server_urls', urls);
        }

        await prefs.setString('server_db_$serverUrl', database);
      } catch (_) {}

      await sessionService.switchToAccount(fixedSession);

      if (mounted) {
        context.goNamed(AppRoutes.app);
      }

      biometricContext.endAccountOperation('add_account');
      provider.setLoading(false);
      return true;
    } catch (e) {
      // Covers any way out that isn't a completed add — including the 2FA
      // hand-off rethrown below, where the OTP screen starts the account
      // over. A no-op once the account was committed above.
      await OdooSessionManager.discardProvisionalSession(
        SessionService.instance.currentSession,
      );
      provider.setLoading(false);
      final msg = e.toString().toLowerCase();
      if (msg.contains('two-factor') ||
          msg.contains('two factor') ||
          msg.contains('2fa') ||
          msg.contains('totp') ||
          msg.contains('token_expired') ||
          (msg.contains('null') && msg.contains('subtype'))) {
        rethrow;
      }
      provider.errorMessage =
          'Failed to add account: ${OdooErrorMapper.toUserMessage(e)}';
      final biometricContext = BiometricContextService();
      biometricContext.endAccountOperation('add_account');
      return false;
    }
  }

  String _ensureScheme(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          return LoginLayout(
            title: widget.isAddingAccount ? 'Add Account' : 'Sign In',
            subtitle: widget.isAddingAccount
                ? 'Enter your credentials'
                : 'Enter your credentials to continue',
            backButton: Positioned(
              top: 24,
              left: 0,
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
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            child: Form(
              key: provider.formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LoginTextField(
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      controller: provider.emailController,
                      hint: widget.isAddingAccount
                          ? 'Email / Username'
                          : 'Email',
                      prefixIcon: HugeIcons.strokeRoundedMail01,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !provider.disableFields,
                      focusNode: _emailFocus,
                      textInputAction: TextInputAction.next,
                      hasError: emailHasError,
                      autovalidateMode: _shouldValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      validator: (value) {
                        if (provider.isLoadingDatabases || !_shouldValidate) {
                          return null;
                        }
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        return null;
                      },
                      onChanged: (val) {
                        setState(() {
                          emailHasError = val.isEmpty;
                          if (inlineError != null) {
                            inlineError = null;
                          }
                        });
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocus);
                      },
                    ),
                    const SizedBox(height: 16),

                    LoginTextField(
                      autofillHints: const [AutofillHints.password],
                      controller: provider.passwordController,
                      hint: 'Password',
                      prefixIcon: HugeIcons.strokeRoundedLockPassword,
                      obscureText: provider.obscurePassword,
                      enabled: !provider.disableFields,
                      focusNode: _passwordFocus,
                      textInputAction: TextInputAction.done,
                      hasError: passwordHasError,
                      autovalidateMode: _shouldValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      validator: (value) {
                        if (provider.isLoadingDatabases || !_shouldValidate) {
                          return null;
                        }
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.isEmpty) {
                          return 'Password must be at least 1 characters';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        icon: Transform.scale(
                          scale: 20 / 24.0,
                          child: HugeIcon(
                            icon: provider.obscurePassword
                                ? HugeIcons.strokeRoundedViewOff
                                : HugeIcons.strokeRoundedView,
                            color: Colors.black54,
                          ),
                        ),
                        onPressed: provider.togglePasswordVisibility,
                      ),
                      onChanged: (val) {
                        setState(() {
                          passwordHasError = val.isEmpty || val.isEmpty;
                          if (inlineError != null) {
                            inlineError = null;
                          }
                        });
                      },
                      onFieldSubmitted: (_) async {
                        if (!(provider.isLoading ||
                            provider.isLoadingDatabases)) {
                          await _handleSubmit(provider);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    if (!widget.isAddingAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: provider.isLoading
                              ? null
                              : () {
                                  context.pushNamed(
                                    AppRoutes.resetPassword,
                                    extra: {
                                      'url': provider.getFullUrl(),
                                      'database': provider.database,
                                    },
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: provider.isLoading
                                  ? Colors.white54
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),

                    LoginErrorDisplay(error: inlineError),

                    LoginButton(
                      text: widget.isAddingAccount ? 'Add Account' : 'Sign In',
                      isLoading: provider.isLoading,
                      loadingWidget: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.isAddingAccount
                                ? 'Adding Account'
                                : 'Signing In',
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
                      ),
                      onPressed:
                          provider.isLoading || provider.isLoadingDatabases
                          ? null
                          : () async {
                              await _handleSubmit(provider);
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
