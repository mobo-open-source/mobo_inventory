import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'login_layout.dart'
    show LoginLayout, LoginTextField, LoginButton, LoginErrorDisplay;

/// Screen for adding a secondary Odoo account to the current server.
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _shouldValidate = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;
  String? _inlineError;
  String? _errorMessage;

  String? _serverUrl;
  String? _database;

  @override
  void initState() {
    super.initState();
    _loadCurrentSessionInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_emailFocus);
      }
    });
  }

  void _loadCurrentSessionInfo() {
    final sessionService = SessionService.instance;
    final currentSession = sessionService.currentSession;

    if (currentSession != null) {
      setState(() {
        _serverUrl = currentSession.serverUrl;
        _database = currentSession.database;
      });
    } else {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    if (_serverUrl == null || _database == null) {
      setState(() {
        _errorMessage = 'No active session found. Please login first.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newSession = await OdooSessionManager.authenticate(
        serverUrl: _serverUrl!,
        database: _database!,
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (newSession == null) {
        setState(() {
          _errorMessage =
              'Authentication failed. Please check your credentials.';
          _isLoading = false;
        });
        return;
      }

      final sessionService = SessionService.instance;
      await sessionService.storeAccount(newSession, _passwordController.text);

      await sessionService.switchToAccount(newSession);

      if (!mounted) return;

      context.goNamed(AppRoutes.app);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          CustomSnackbar.showSuccess(
            context,
            'Account added and switched successfully',
          );
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add account: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != _inlineError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _inlineError = _errorMessage;
        });
      });
    }

    return LoginLayout(
      title: 'Add Account',
      subtitle: 'Add another account to the same server',
      backButton: Positioned(
        top: 24,
        left: 0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.pop(),
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
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoginTextField(
              controller: _emailController,
              hint: 'Email',
              prefixIcon: HugeIcons.strokeRoundedMail01,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              focusNode: _emailFocus,
              hasError: _emailHasError,
              autovalidateMode: _shouldValidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              validator: (value) {
                if (!_shouldValidate) return null;
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
              onChanged: (val) {
                setState(() {
                  _emailHasError = val.isEmpty;
                  if (_inlineError != null) {
                    _inlineError = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            LoginTextField(
              controller: _passwordController,
              hint: 'Password',
              prefixIcon: HugeIcons.strokeRoundedLockPassword,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              focusNode: _passwordFocus,
              hasError: _passwordHasError,
              autovalidateMode: _shouldValidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              validator: (value) {
                if (!_shouldValidate) return null;
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.isEmpty) {
                  return 'Password must be at least 1 character';
                }
                return null;
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              onChanged: (val) {
                setState(() {
                  _passwordHasError = val.isEmpty || val.isEmpty;
                  if (_inlineError != null) {
                    _inlineError = null;
                  }
                });
              },
            ),
            SizedBox(height: _inlineError != null ? 16 : 0),

            LoginErrorDisplay(error: _inlineError),

            LoginButton(
              text: 'Add Account',
              isLoading: _isLoading,
              loadingWidget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Adding Account',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LoadingWidget(
                    color: Colors.white,
                    size: 28,
                    variant: LoadingVariant.staggeredDots,
                  ),
                ],
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _shouldValidate = true;
                      });

                      final formValid =
                          _formKey.currentState?.validate() ?? false;
                      setState(() {
                        _emailHasError = _emailController.text.isEmpty;
                        final pwd = _passwordController.text;
                        _passwordHasError = pwd.isEmpty || pwd.isEmpty;
                        _inlineError = null;
                      });

                      if (!formValid) {
                        await HapticFeedback.lightImpact();
                        return;
                      }

                      await _addAccount();

                      if (!mounted) return;
                      if (_errorMessage != null) {
                        await HapticFeedback.heavyImpact();
                        setState(() {
                          _inlineError = _errorMessage;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
