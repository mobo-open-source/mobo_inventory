import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math' as math;

/// A shared layout wrapper for all login-related screens.
/// Provides a consistent background, header, and styling.
class LoginLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? backButton;

  const LoginLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage('assets/images/loginbg.png'),
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

          LayoutBuilder(
            builder: (context, viewportConstraints) {
              return Column(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 68),
                      child: _buildAppHeader(),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewportConstraints.maxHeight - 180,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSignInHeader(),
                                  const SizedBox(height: 40),

                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme: Theme.of(context)
                                          .inputDecorationTheme
                                          .copyWith(
                                            errorStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.red[900]!,
                                                width: 1.0,
                                              ),
                                            ),
                                            focusedErrorBorder:
                                                OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: const BorderSide(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                    ),
                                    child: child,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if (backButton != null) backButton!,
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/app-logo/inventory-icon.svg',
          width: 28,
          height: 28,
          fit: BoxFit.fitWidth,
          color: Colors.white,
        ),
        const SizedBox(width: 12),
        Text(
          'mobo inventory',
          style: const TextStyle(
            fontFamily: 'YaroRg',
            color: Colors.white,
            fontSize: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInHeader() {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          subtitle,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final List<String>? autofillHints;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.suffixIcon,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autofillHints: autofillHints,
      cursorColor: Colors.black,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(.4),
        ),
        prefixIcon: Icon(prefixIcon, size: 20),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? Colors.black26
              : Colors.black54,
        ),
        suffixIcon: hasError
            ? Icon(Icons.error_outline, color: Colors.red, size: 20)
            : suffixIcon,
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
      ),
    );
  }
}

class LoginDropdownField extends StatefulWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final bool hasError;
  final AutovalidateMode? autovalidateMode;

  const LoginDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
    this.hasError = false,
    this.autovalidateMode,
  });

  @override
  State<LoginDropdownField> createState() => _LoginDropdownFieldState();
}

class _LoginDropdownFieldState extends State<LoginDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _handleMenuOpen(BuildContext context) async {
    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _showDropdownOverlay();
  }

  void _showDropdownOverlay() {
    final uniqueItems = widget.items.toSet().toList();
    if (uniqueItems.isEmpty) return;
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);

    final fieldOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final screenHeight = MediaQuery.of(context).size.height;
    final fieldHeight = renderBox?.size.height ?? 0;
    final availableBelow = screenHeight - (fieldOffset.dy + fieldHeight) - 16;

    const double itemHeight = 44.0;
    const double listVerticalPadding = 16.0;
    final double heightForFiveItems = itemHeight * 5 + listVerticalPadding;
    final double maxDropdownHeight = math.max(
      120.0,
      math.min(availableBelow, heightForFiveItems),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideDropdown,
            ),
          ),
          Positioned(
            width: fieldWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 58),
              child: Material(
                elevation: 12.0,
                color: Colors.white,
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
                    constraints: BoxConstraints(maxHeight: maxDropdownHeight),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemExtent: itemHeight,
                      itemCount: uniqueItems.length,
                      itemBuilder: (context, index) {
                        final item = uniqueItems[index];
                        return InkWell(
                          onTap: () {
                            widget.onChanged?.call(item);
                            _hideDropdown();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Text(
                              item,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
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
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
      }
    });
  }

  void _hideDropdown() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final uniqueItems = widget.items.toSet().toList();
    final safeValue = uniqueItems.contains(widget.value) ? widget.value : null;
    final bool isEnabled = widget.onChanged != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: FormField<String>(
        initialValue: safeValue,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        builder: (field) {
          final externalValue = uniqueItems.contains(widget.value)
              ? widget.value
              : null;
          if (field.value != externalValue) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              field.didChange(externalValue);
            });
          }

          final effectiveValue = externalValue;
          final showErrorIcon =
              widget.hasError &&
              (effectiveValue == null || effectiveValue.isEmpty);

          return Builder(
            builder: (rowCtx) {
              return InkWell(
                onTap: () => _handleMenuOpen(rowCtx),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  isEmpty: (effectiveValue == null || effectiveValue.isEmpty),
                  decoration: InputDecoration(
                    enabled: isEnabled,
                    prefixIcon: Icon(Icons.storage, size: 20),
                    prefixIconColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.black26
                          : Colors.black54,
                    ),
                    suffixIcon: showErrorIcon
                        ? Icon(Icons.error, color: Colors.red[900], size: 20)
                        : InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (_overlayEntry == null) {
                                _handleMenuOpen(rowCtx);
                              } else {
                                _hideDropdown();
                              }
                            },
                            child: Icon(
                              _overlayEntry == null
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 20,
                              color: isEnabled
                                  ? Colors.black54
                                  : Colors.black26,
                            ),
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
                    errorText: field.errorText,
                    errorStyle: const TextStyle(color: Colors.white),
                  ),
                  child: Text(
                    effectiveValue ?? widget.hint,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: (effectiveValue == null || effectiveValue.isEmpty)
                          ? Colors.black.withOpacity(.4)
                          : Colors.black,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LoginErrorDisplay extends StatelessWidget {
  final String? error;

  const LoginErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: error != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class LoginUrlTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final String selectedProtocol;
  final ValueChanged<String>? onProtocolChanged;
  final bool isLoading;

  final VoidCallback? onProtocolAutoDetected;

  const LoginUrlTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.selectedProtocol = 'https://',
    this.onProtocolChanged,
    this.isLoading = false,
    this.onProtocolAutoDetected,
  });

  @override
  State<LoginUrlTextField> createState() => _LoginUrlTextFieldState();
}

class _LoginUrlTextFieldState extends State<LoginUrlTextField> {
  bool _isAdjustingText = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleTypedProtocolInField);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTypedProtocolInField);
    super.dispose();
  }

  void _handleTypedProtocolInField() {
    if (_isAdjustingText) return;
    final raw = widget.controller.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    String? detectedProtocol;
    String domain = text;

    if (text.startsWith('http://')) {
      detectedProtocol = 'http://';
      domain = text.substring(7);
    } else if (text.startsWith('https://')) {
      detectedProtocol = 'https://';
      domain = text.substring(8);
    }

    if (detectedProtocol != null) {
      widget.onProtocolAutoDetected?.call();
      _isAdjustingText = true;
      try {
        if (widget.onProtocolChanged != null &&
            widget.selectedProtocol != detectedProtocol) {
          widget.onProtocolChanged!(detectedProtocol);
        }

        if (domain != raw) {
          widget.controller
            ..text = domain
            ..selection = TextSelection.collapsed(offset: domain.length);

          widget.onChanged?.call(domain);
        }
      } finally {
        _isAdjustingText = false;
      }
    }
  }

  Future<void> _handleProtocolMenuOpen(BuildContext context) async {
    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _openProtocolMenu(context);
  }

  Future<void> _openProtocolMenu(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size size = button.size;

    final selected = await showMenu<String>(
      context: context,
      color: Colors.white,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(offset.dx, offset.dy + size.height, size.width, 0),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(minWidth: size.width, maxWidth: size.width),
      items: ['http://', 'https://']
          .map(
            (p) => PopupMenuItem<String>(
              value: p,
              child: Text(
                p,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null && mounted) {
      widget.onProtocolChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.black,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(.4),
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                widget.prefixIcon,
                size: 20,
                color: widget.enabled ? Colors.black54 : Colors.black26,
              ),
            ),

            Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.black.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Builder(
                builder: (ctx) {
                  return InkWell(
                    onTap: () => _handleProtocolMenuOpen(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.selectedProtocol,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.enabled
                                  ? Colors.black
                                  : Colors.black26,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: widget.enabled
                                ? Colors.black54
                                : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.hasError
            ? Icon(Icons.error_outline, color: Colors.red, size: 20)
            : widget.isLoading
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.only(
          left: 0,
          right: 20,
          top: 16,
          bottom: 16,
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? loadingWidget;

  const LoginButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withOpacity(.2),
          disabledForegroundColor: Colors.white,
          overlayColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading && loadingWidget != null
            ? loadingWidget!
            : Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
