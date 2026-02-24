import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/login_provider.dart';
import '../../../core/routing/app_routes.dart';
import 'login_layout.dart';

/// Initial screen for configuring the Odoo server URL and selecting a database.
class ServerSetupScreen extends StatefulWidget {
  final bool isAddingAccount;
  final LoginProvider? provider;
  final String? initialUrl;
  final String? initialDatabase;

  const ServerSetupScreen({
    super.key,
    this.isAddingAccount = false,
    this.provider,
    this.initialUrl,
    this.initialDatabase,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _databaseFadeController;
  late Animation<double> _databaseFadeAnimation;

  bool _shouldValidate = false;

  bool urlHasError = false;
  bool dbHasError = false;

  String? inlineError;

  Timer? _urlDebounce;

  bool _awaitingSuggestionSelection = false;

  @override
  void initState() {
    super.initState();
    _databaseFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _databaseFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _databaseFadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _databaseFadeController.dispose();
    super.dispose();
  }

  void _handleDatabaseFetch(LoginProvider provider) {
    if (provider.urlCheck && provider.dropdownItems.isNotEmpty) {
      _databaseFadeController.forward();
    } else if (!provider.urlCheck || provider.dropdownItems.isEmpty) {
      _databaseFadeController.reverse();
    }
  }

  void _goToCredentials(LoginProvider provider) {
    context.pushNamed(
      AppRoutes.login,
      extra: {
        'url': provider.getFullUrl(),
        'database': provider.database!,
        'isAddingAccount': widget.isAddingAccount,
      },
    );
  }

  bool _canProceedToCredentials(LoginProvider provider) {
    return provider.urlController.text.trim().isNotEmpty &&
        provider.database != null &&
        provider.database!.isNotEmpty &&
        !provider.isLoadingDatabases &&
        provider.urlCheck;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginProvider>(
      create: (_) {
        final provider = widget.provider ?? LoginProvider();

        if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
          provider.setUrlFromFullUrl(widget.initialUrl!);

          if (widget.initialDatabase != null &&
              widget.initialDatabase!.isNotEmpty) {
            provider.setDatabase(widget.initialDatabase);
            if (provider.isValidUrl(provider.urlController.text)) {
              Future.microtask(() => provider.fetchDatabaseList());
            }
          }
        }
        return provider;
      },
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          _handleDatabaseFetch(provider);

          if (!provider.isLoadingDatabases &&
              provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: LoginLayout(
              title: 'Sign In',
              subtitle: 'Configure your server connection',
              child: Form(
                key: provider.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomAutocompleteField(
                      controller: provider.urlController,
                      suggestions: provider.previousUrls,
                      enableSuggestions:
                          !provider.isLoadingDatabases &&
                          !(provider.urlCheck &&
                              provider.dropdownItems.isNotEmpty),
                      onSuggestionSelected: (String selection) {
                        provider.setUrlFromFullUrl(selection);

                        provider.seedUrlToHistory(selection);

                        final domain = provider.extractDomain(selection);

                        setState(() {
                          urlHasError = domain.isEmpty;

                          _awaitingSuggestionSelection = false;
                        });

                        if (domain.trim().isNotEmpty) {
                          _urlDebounce?.cancel();
                          if (!provider.isLoadingDatabases &&
                              provider.isValidUrl(domain)) {
                            setState(() {
                              dbHasError = false;
                              inlineError = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                            provider.fetchDatabaseList();
                          }
                        }
                      },
                      child: LoginUrlTextField(
                        controller: provider.urlController,
                        hint: 'Enter Server Address',
                        prefixIcon: Icons.dns,
                        enabled: !provider.disableFields,
                        hasError: urlHasError,
                        selectedProtocol: provider.selectedProtocol,
                        isLoading: provider.isLoadingDatabases,
                        onProtocolAutoDetected: () {
                          setState(() {
                            _awaitingSuggestionSelection = false;
                            inlineError = null;
                            dbHasError = false;
                            _shouldValidate = false;
                          });
                          _urlDebounce?.cancel();
                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty &&
                              provider.isValidUrl(trimmed)) {
                            provider.formKey.currentState?.validate();
                            provider.fetchDatabaseList();
                          }
                        },
                        autovalidateMode: _shouldValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        validator: (value) {
                          if (provider.isLoadingDatabases || !_shouldValidate) {
                            return null;
                          }
                          if (value == null || value.isEmpty) {
                            return 'Server URL is required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final newUrlHasError = val.isEmpty;
                          if (urlHasError != newUrlHasError ||
                              dbHasError ||
                              inlineError != null ||
                              _shouldValidate) {
                            setState(() {
                              urlHasError = newUrlHasError;
                              dbHasError = false;
                              inlineError = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                          }

                          _urlDebounce?.cancel();
                          final trimmed = val.trim();
                          if (trimmed.isEmpty) {
                            provider.fetchDatabaseList();
                          } else {
                            _urlDebounce = Timer(
                              const Duration(milliseconds: 700),
                              () {
                                if (!mounted) return;
                                if (_awaitingSuggestionSelection) {
                                  return;
                                }
                                if (provider.isValidUrl(trimmed)) {
                                  if (dbHasError || inlineError != null) {
                                    setState(() {
                                      dbHasError = false;
                                      inlineError = null;
                                    });
                                    provider.formKey.currentState?.validate();
                                  }
                                  provider.fetchDatabaseList();
                                }
                              },
                            );
                          }
                        },
                        onProtocolChanged: (protocol) {
                          provider.setProtocol(protocol);

                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty &&
                              provider.isValidUrl(trimmed)) {
                            _urlDebounce?.cancel();
                            _urlDebounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (!mounted) return;
                                if (_awaitingSuggestionSelection) {
                                  return;
                                }
                                provider.fetchDatabaseList();
                              },
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    AnimatedBuilder(
                      animation: _databaseFadeAnimation,
                      builder: (context, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _databaseFadeAnimation.value > 0 ? null : 0,
                          child: Opacity(
                            opacity: _databaseFadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                (1 - _databaseFadeAnimation.value) * -20,
                              ),
                              child: Column(
                                children: [
                                  LoginDropdownField(
                                    hint: provider.isLoadingDatabases
                                        ? 'Loading...'
                                        : provider.errorMessage != null
                                        ? 'Unable to load'
                                        : 'Database',
                                    value: provider.database,
                                    items:
                                        provider.urlCheck &&
                                            provider.dropdownItems.isNotEmpty
                                        ? provider.dropdownItems
                                        : [],
                                    onChanged:
                                        (provider.disableFields ||
                                            provider.isLoadingDatabases)
                                        ? null
                                        : (val) {
                                            provider.setDatabase(val);
                                            setState(() {
                                              dbHasError =
                                                  (val == null || val.isEmpty);
                                              inlineError = null;
                                            });
                                            provider.formKey.currentState
                                                ?.validate();
                                          },
                                    validator: (value) {
                                      if (provider.isLoadingDatabases ||
                                          !_shouldValidate) {
                                        return null;
                                      }
                                      if (value == null || value.isEmpty) {
                                        return 'Database is required';
                                      }
                                      return null;
                                    },
                                    hasError: dbHasError,
                                    autovalidateMode: _shouldValidate
                                        ? AutovalidateMode.onUserInteraction
                                        : AutovalidateMode.disabled,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    LoginErrorDisplay(error: inlineError),

                    LoginButton(
                      text: 'Next',
                      onPressed: _canProceedToCredentials(provider)
                          ? () => _goToCredentials(provider)
                          : null,
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

class _CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;
  final Widget child;
  final bool enableSuggestions;

  const _CustomAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.child,
    this.enableSuggestions = true,
  });

  @override
  State<_CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<_CustomAutocompleteField> {
  bool _showSuggestions = false;
  List<String> _filteredSuggestions = [];
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_CustomAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.suggestions != widget.suggestions) {
      if (_focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!widget.enableSuggestions) {
            _hideSuggestions();
            return;
          }
          _updateSuggestions();
          if (_filteredSuggestions.isNotEmpty && _overlayEntry == null) {
            _showSuggestionsOverlay();
          } else if (_overlayEntry != null) {
            try {
              _overlayEntry!.markNeedsBuild();
            } catch (_) {}
          }
        });
      }
    }

    if (oldWidget.enableSuggestions && !widget.enableSuggestions) {
      _hideSuggestions();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) return;
      _updateSuggestions();
      if (_filteredSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      }
    } else {
      _hideSuggestions();
    }
  }

  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) {
        _hideSuggestions();
        return;
      }
      _updateSuggestions();
      if (_overlayEntry != null) {
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) {
          _overlayEntry!.markNeedsBuild();
        } else {
          _removeOverlay();
        }
      }
    }
  }

  void _updateSuggestions() {
    final text = widget.controller.text.toLowerCase().trim();

    if (!widget.enableSuggestions) {
      _filteredSuggestions = [];
      if (!mounted) return;
      setState(() {
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    if (text.isEmpty) {
      _filteredSuggestions = List.from(widget.suggestions);
    } else {
      _filteredSuggestions = widget.suggestions.where((suggestion) {
        final suggestionLower = suggestion.toLowerCase();

        if (text.startsWith('http://') || text.startsWith('https://')) {
          return suggestionLower.startsWith(text);
        }

        final textDomain = _extractDomainFromUrl(text);
        final suggestionDomain = _extractDomainFromUrl(suggestionLower);
        if (suggestionDomain.startsWith(textDomain)) {
          return true;
        }

        return suggestionLower.contains(textDomain);
      }).toList();
    }

    for (int i = 0; i < _filteredSuggestions.length; i++) {}

    if (!mounted) return;
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty;
    });

    if (_overlayEntry != null) {
      if (_filteredSuggestions.isEmpty) {
        _removeOverlay();
      } else {
        try {
          _overlayEntry!.markNeedsBuild();
        } catch (_) {}
      }
    } else if (_filteredSuggestions.isNotEmpty) {
      _showSuggestionsOverlay();
    }
  }

  String _extractDomainFromUrl(String url) {
    if (url.startsWith('https://')) {
      return url.substring(8);
    } else if (url.startsWith('http://')) {
      return url.substring(7);
    }
    return url;
  }

  void _showSuggestionsOverlay() {
    if (_filteredSuggestions.isEmpty || !widget.enableSuggestions) {
      return;
    }

    if (_overlayEntry != null) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hoverColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 12.0,
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: _filteredSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _filteredSuggestions[index];
                    return InkWell(
                      onTap: () {
                        widget.onSuggestionSelected(suggestion);
                        _hideSuggestions();
                        _focusNode.unfocus();
                      },
                      hoverColor: hoverColor,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                suggestion,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
      } else {}
    });
  }

  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(focusNode: _focusNode, child: widget.child),
    );
  }
}
