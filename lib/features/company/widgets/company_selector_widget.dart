import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import '../../../core/services/session_service.dart';
import '../providers/company_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../main.dart';

/// A comprehensive company selector widget with two modes:
/// 2. Expanded mode: Bottom sheet with multi-select for allowed companies
class CompanySelectorWidget extends StatefulWidget {
  final bool showMultiSelect;
  final VoidCallback? onCompanyChanged;

  const CompanySelectorWidget({
    super.key,
    this.showMultiSelect = false,
    this.onCompanyChanged,
  });

  @override
  State<CompanySelectorWidget> createState() => _CompanySelectorWidgetState();
}

class _CompanySelectorWidgetState extends State<CompanySelectorWidget> {
  // Tracks which session (userId@serverUrl) we last initialised for.
  // Null = not yet initialised. On account switch the tuple changes, so the
  // widget detects it and re-runs `CompanyProvider.initialize()` against the
  // new session instead of rendering the previous account's company name.
  String? _initialisedFor;

  // Guards the *automatic* retry-on-error path so a persistent failure (e.g.
  // the server staying unreachable) retries exactly once instead of looping
  // forever: initialize() fails -> notifyListeners() -> rebuild -> error is
  // still non-null -> without this flag we'd schedule another initialize()
  // immediately, fail again, and repeat indefinitely (looks like it's stuck
  // "Loading..." because it never actually stops retrying). Manual taps on
  // the empty-state pill always go through regardless of this flag.
  bool _hasAutoRetriedThisFailure = false;

  String? _sessionKey(SessionService session) {
    final s = session.currentSession;
    if (s == null) return null;
    return '${s.userId}@${s.serverUrl}#${s.database}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CompanyProvider, SessionService>(
      builder: (context, provider, session, _) {
        final sessionKey = _sessionKey(session);

        // Re-run initialize when: first mount with no data, the logged-in user
        // changed (account switch), or the previous attempt failed (e.g. the
        // server was unreachable) — otherwise a single failed load would leave
        // the pill permanently stuck on "No companies" for the rest of the
        // session. Skip while already loading, skip once companies are
        // successfully loaded (avoid refetching on every tab switch), and
        // only auto-retry a given failure once to avoid retry-fail-retry
        // looping (the dashboard's own Retry action also re-triggers this
        // provider directly, so there's still a way to recover manually).
        final isNewSession = sessionKey != null && sessionKey != _initialisedFor;
        if (isNewSession) {
          _initialisedFor = sessionKey;
          _hasAutoRetriedThisFailure = false;
        }
        final shouldAutoRetry = provider.companies.isEmpty &&
            !provider.isLoading &&
            (isNewSession ||
                (provider.error != null && !_hasAutoRetriedThisFailure));
        if (shouldAutoRetry) {
          _hasAutoRetriedThisFailure = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) provider.initialize();
          });
        }

        if (provider.isLoading && provider.companies.isEmpty) {
          return _buildLoadingState(context);
        }

        if (provider.companies.isEmpty) {
          return _buildEmptyState(context, provider);
        }

        return _buildCompactDropdown(context, provider);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CompanyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(
            'No companies',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCompactDropdown(BuildContext context, CompanyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final rawName = provider.selectedCompany?['name']?.toString() ?? 'Select Company';
    final displayName = formatCompanyName(rawName);


    return InkWell(
      onTap: () => _showDropdownMenu(context, provider),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, size: 16, color: textColor),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            if (provider.isLoading || provider.isSwitching) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 18),
          ],
        ),
      ),
    );
  }



  void _showDropdownMenu(BuildContext context, CompanyProvider provider) async {
    // Always refetch on open to ensure we display up-to-date companies
    // Fire-and-forget so the UI opens immediately but shows a spinner while loading
    // This will set provider.isLoading = true and the compact button shows spinner
    // The dropdown content will rebuild via Provider/Consumer if used inside
    // broader widgets; here we keep it simple and rely on provider state
    // management to refresh the entries.
    // ignore: unawaited_futures
    provider.initialize();
    final screenSize = MediaQuery.of(context).size;
    // Use bottom sheet on very narrow screens
    if (screenSize.width < 1000) {
      // Same width cap as the filter sheet, so rows aren't stretched across a
      // phone in landscape.
      final sheetWidth = math.min(screenSize.width, 640.0);
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        constraints: BoxConstraints(maxWidth: sheetWidth),
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Flexible: on a short screen (a phone in landscape) the list
                // shrinks to the sheet's height and scrolls, rather than
                // keeping its 480px cap and overflowing.
                Flexible(
                  child: _CompanyDropdownContent(
                    provider: provider,
                    onCompanyChanged: widget.onCompanyChanged,
                    width: sheetWidth, // take full width inside sheet
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    // Popover for wider screens; clamp within viewport and set responsive width
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    final double popoverWidth = math.min(360, screenSize.width - 24);
    final double left = math.max(
      12,
      math.min(buttonPosition.dx, screenSize.width - popoverWidth - 12),
    );
    final double top = math.min(
      buttonPosition.dy + buttonSize.height + 4,
      screenSize.height - 16 - 300, // leave room at bottom
    );

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 4,
                color: isDark ? AppTheme.darkPopupSurface : Colors.white,
                surfaceTintColor: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: popoverWidth,
                    maxHeight: 320,
                  ),
                  child: _CompanyDropdownContent(
                    provider: provider,
                    onCompanyChanged: widget.onCompanyChanged,
                    width: popoverWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
  String formatCompanyName(String name) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    return match != null ? match.group(1)! : name;
  }
}

class _CompanyDropdownContent extends StatefulWidget {
  final CompanyProvider provider;
  final VoidCallback? onCompanyChanged;
  final double? width;

  const _CompanyDropdownContent({
    required this.provider,
    this.onCompanyChanged,
    this.width,
  });

  @override
  State<_CompanyDropdownContent> createState() =>
      _CompanyDropdownContentState();
}

class _CompanyDropdownContentState extends State<_CompanyDropdownContent> {
  late int _tempSelectedCompanyId;
  late Set<int> _tempAllowedCompanyIds;
  bool _applying = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedCompanyId = widget.provider.selectedCompanyId ?? -1;
    _tempAllowedCompanyIds = widget.provider.selectedAllowedCompanyIds.toSet();
  }

  void _onConfirm() async {
    // If nothing changed, just close
    final noActiveChange = _tempSelectedCompanyId == widget.provider.selectedCompanyId;
    final noAllowedChange = _setEquals(
      _tempAllowedCompanyIds,
      widget.provider.selectedAllowedCompanyIds.toSet(),
    );
    if (noActiveChange && noAllowedChange) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _applying = true);
    bool changed = false;

    try {
      // 1. Switch active company if changed
      if (!noActiveChange) {
        await widget.provider.switchCompany(_tempSelectedCompanyId);
        changed = true;
      }

      if (!noAllowedChange) {
        await widget.provider.setAllowedCompanies(
          _tempAllowedCompanyIds.toList(),
        );
        changed = true;
      }

      if (changed) {
        widget.onCompanyChanged?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _applying = false);
        Navigator.pop(context);
      }
    }
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // No fill of its own: the host (bottom sheet or popover) supplies the
    // surface colour and radius.
    return Container(
      width: widget.width ?? 280,
      constraints: const BoxConstraints(maxHeight: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner (if any)
          if (widget.provider.error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: StatusColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: StatusColors.red.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: StatusColors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.provider.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Company list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.provider.companies.length,
              itemBuilder: (context, index) {
                final company = widget.provider.companies[index];
                final companyId = company['id'] as int;
                final companyName = company['name']?.toString() ?? '-';

                final isActive = companyId == _tempSelectedCompanyId;
                final isAllowed = _tempAllowedCompanyIds.contains(companyId);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Material(
                    color: isActive
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _applying ? null : () {
                        setState(() {
                          _tempSelectedCompanyId = companyId;
                          _tempAllowedCompanyIds.add(companyId);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                companyName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: MoboCheckbox(
                                value: isAllowed,
                                onChanged: _applying
                                    ? null
                                    : (companyId == _tempSelectedCompanyId)
                                    ? null
                                    : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _tempAllowedCompanyIds.add(companyId);
                                    } else {
                                      _tempAllowedCompanyIds.remove(companyId);
                                    }
                                  });
                                },
                                size: 26,
                                radius: AppRadius.xs,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (_applying || _resetting)
                          ? null
                          : () async {
                              setState(() => _resetting = true);
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('selected_allowed_company_ids');
                                await prefs.remove('selected_company_id');

                                await widget.provider.initialize();
                                if (mounted) {
                                  setState(() {
                                    _tempSelectedCompanyId =
                                        widget.provider.selectedCompanyId ?? -1;
                                    _tempAllowedCompanyIds = widget
                                        .provider
                                        .selectedAllowedCompanyIds
                                        .toSet();
                                  });
                                  final ctx = navigatorKey.currentContext;
                                  if (ctx != null && ctx.mounted) {
                                    CustomSnackbar.showSuccess(ctx, 'Synced with server');
                                  }
                                }
                              } finally {
                                if (mounted) setState(() => _resetting = false);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        minimumSize: const Size(double.infinity, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        side: BorderSide(color: primaryColor, width: 1.5),
                      ),
                      child: _resetting
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            )
                          : Text(
                              'Reset',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final noActiveChange =
                            _tempSelectedCompanyId == widget.provider.selectedCompanyId;
                        final noAllowedChange = _setEquals(
                          _tempAllowedCompanyIds,
                          widget.provider.selectedAllowedCompanyIds.toSet(),
                        );
                        final disabled = _applying ||
                            _resetting ||
                            widget.provider.isSwitching ||
                            (noActiveChange && noAllowedChange);
                        if (!disabled) _onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 0,
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _applying
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Applying...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Confirm',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
