import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../providers/login_provider.dart';
import 'login_layout.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/biometric_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/haptics_service.dart';
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

      final newSession = await OdooSessionManager.authenticate(
        serverUrl: serverUrl,
        database: database,
        username: provider.emailController.text.trim(),
        password: provider.passwordController.text,
      );

      if (newSession == null) {
        provider.errorMessage =
            'Authentication failed. Please check your credentials.';
        biometricContext.endAccountOperation('add_account');
        provider.setLoading(false);
        return false;
      }

      await sessionService.storeAccount(
        newSession,
        provider.passwordController.text,
        markAsCurrent: true,
      );

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

      await sessionService.switchToAccount(newSession);

      if (mounted) {
        context.goNamed(AppRoutes.app);
      }

      biometricContext.endAccountOperation('add_account');
      provider.setLoading(false);
      return true;
    } catch (e) {
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
      provider.errorMessage = 'Failed to add account: ${e.toString()}';
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
                ? 'Enter credentials for the new account'
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
                    child: const Icon(
                      HugeIcons.strokeRoundedArrowLeft01,
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
                      hint: 'Email',
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
                        icon: Icon(
                          provider.obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black54,
                          size: 20,
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

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          context.pushNamed(
                            AppRoutes.resetPassword,
                            extra: {
                              'url': widget.url,
                              'database': widget.database,
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
                            color: Colors.white70,
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
                          SizedBox(width: 12),
                          LoadingWidget(
                            color: Colors.white,
                            size: 28,
                            variant: LoadingVariant.staggeredDots,
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
