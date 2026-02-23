import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/widgets/section_card.dart';
import '../widgets/switch_tile.dart';
import '../widgets/odoo_dropdown_tile.dart';
import '../../../shared/widgets/action_tile.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';

import '../../dashboard/providers/dashboard_provider.dart';
import '../../inventory/providers/inventory_product_provider.dart';
import '../../transfer/providers/transfer_provider.dart';
import '../../adjustment/providers/adjustment_provider.dart';
import '../../move_history/providers/move_history_provider.dart';
import '../../profile/providers/profile_provider.dart';

/// A screen for managing application-wide settings and preferences.
///
/// Allows users to configure appearance (dark mode), security (biometrics),
/// language & region settings, and provides access to help, support, and cache management.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  int _cacheUpdateKey = 0;

  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  String _authStatusDescription = 'Checking authentication status...';

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _loadBiometricSettings();
  }

  Future<void> _initializeSettings() async {
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.initialize();
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final isEnabled = await BiometricService.isBiometricEnabled();
      final isAvailable = await BiometricService.isBiometricAvailable();
      final description = isAvailable
          ? (isEnabled
                ? 'Biometric authentication is enabled'
                : 'Biometric authentication is available but disabled')
          : 'Biometric authentication is not available on this device';

      if (mounted) {
        setState(() {
          _isBiometricEnabled = isEnabled;
          _isBiometricAvailable = isAvailable;
          _authStatusDescription = description;
        });
      }
    } catch (e) {}
  }

  Future<void> _toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final canAuthenticate =
            await BiometricService.authenticateWithBiometrics(
              reason: 'Authenticate to enable biometric login',
            );
        if (!canAuthenticate) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              'Authentication failed. Biometric authentication not enabled.',
            );
          }
          return;
        }
      }

      await BiometricService.setBiometricEnabled(enabled);
      await _loadBiometricSettings();

      if (mounted) {
        if (enabled) {
          CustomSnackbar.showSuccess(
            context,
            'Biometric authentication enabled successfully',
          );
        } else {
          CustomSnackbar.showInfo(context, 'Biometric authentication disabled');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to ${enabled ? 'enable' : 'disable'} biometric authentication: $e',
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = context.read<SettingsProvider>();
    final bool hasDataToClear = (settingsProvider.cacheSize > 0);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          hasDataToClear ? 'Clear Cache' : 'Nothing to Clear',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          hasDataToClear
              ? 'This will clear ${settingsProvider.cacheSize.toStringAsFixed(1)} MB of temporary data and reset all cached data. This action cannot be undone. Are you sure you want to continue?'
              : 'No cached data to clear right now.',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          if (hasDataToClear)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                  ),
                  child: const Text('Clear Cache'),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('OK'),
            ),
        ],
      ),
    );

    if (confirmed != true || !hasDataToClear) return;

    setState(() => _isLoading = true);

    try {
      await settingsProvider.clearCache(
        onClearProviderCaches: () async {
          try {
            final dashboardProvider = context.read<DashboardProvider>();
            dashboardProvider.resetState();

            final inventoryProvider = context.read<InventoryProductProvider>();
            inventoryProvider.resetState();

            final transferProvider = context.read<TransferProvider>();
            transferProvider.resetState();

            final adjustmentProvider = context.read<AdjustmentProvider>();
            adjustmentProvider.resetState();

            final moveHistoryProvider = context.read<MoveHistoryProvider>();
            moveHistoryProvider.resetState();

            final profileProvider = context.read<ProfileProvider>();
            profileProvider.resetState();
          } catch (e) {}
        },
      );

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() => _cacheUpdateKey++);
        CustomSnackbar.showSuccess(context, 'Cache cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to clear cache: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: LoadingWidget(
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      size: 50,
                      variant: LoadingVariant.fourRotatingDots,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Logging out...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final biometricContext = BiometricContextService();
      biometricContext.startAccountOperation('logout');

      await OdooSessionManager.logout();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await Future.delayed(const Duration(milliseconds: 100));

      if (context.mounted) {
        Navigator.of(context).pop();
        context.goNamed(AppRoutes.app);

        Future.delayed(const Duration(milliseconds: 300), () {
          final rootContext = AppRouter.rootNavigatorKey.currentContext;
          if (rootContext != null && rootContext.mounted) {
            CustomSnackbar.showSuccess(rootContext, 'Logged out successfully');
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        CustomSnackbar.showError(context, 'Logout failed: $e');
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out? Your session will be ended.',
      confirmText: 'Log Out',
      cancelText: 'Cancel',
      destructive: true,
      icon: HugeIcons.strokeRoundedLogout01,
    );

    if (confirmed == true && context.mounted) {
      await _performLogout(context);
    }
  }

  Widget _buildAboutContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionTile(
            title: 'Visit Website',
            subtitle: 'www.cybrosys.com',
            icon: HugeIcons.strokeRoundedGlobe02,
            onTap: () => _launchUrlSmart(
              'https://www.cybrosys.com/',
              title: 'Our Website',
            ),
          ),
          ActionTile(
            title: 'Contact Us',
            subtitle: 'info@cybrosys.com',
            icon: HugeIcons.strokeRoundedMail01,
            onTap: () => _launchUrlSmart('mailto:info@cybrosys.com'),
          ),

          if (Theme.of(context).platform == TargetPlatform.android)
            ActionTile(
              title: 'More Apps',
              subtitle: 'View our other apps on Play Store',
              icon: HugeIcons.strokeRoundedPlayStore,
              onTap: () => _launchUrlSmart(
                'https://play.google.com/store/apps/dev?id=7163004064816759344&pli=1',
                title: 'Play Store',
              ),
            ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            ActionTile(
              title: 'More Apps',
              subtitle: 'View our other apps on App Store',
              icon: HugeIcons.strokeRoundedAppStore,
              onTap: () => _launchUrlSmart(
                'https://apps.apple.com/in/developer/cybrosys-technologies/id1805306445',
                title: 'App Store',
              ),
            ),

          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
          const SizedBox(height: 16),

          Center(
            child: Text(
              'Follow Us',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                context,
                'assets/images/social/facebook.png',
                const Color(0xFF1877F2),
                'Facebook',
                () => _launchUrlSmart(
                  'https://www.facebook.com/cybrosystechnologies',
                  title: 'Facebook',
                ),
              ),
              _buildSocialButton(
                context,
                'assets/images/social/linkedin.png',
                const Color(0xFF0077B5),
                'LinkedIn',
                () => _launchUrlSmart(
                  'https://www.linkedin.com/company/cybrosys/',
                  title: 'LinkedIn',
                ),
              ),
              _buildSocialButton(
                context,
                'assets/images/social/instagram.png',
                const Color(0xFFE4405F),
                'Instagram',
                () => _launchUrlSmart(
                  'https://www.instagram.com/cybrosystech/',
                  title: 'Instagram',
                ),
              ),
              _buildSocialButton(
                context,
                'assets/images/social/youtube.png',
                const Color(0xFFFF0000),
                'YouTube',
                () => _launchUrlSmart(
                  'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
                  title: 'YouTube',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${DateTime.now().year} Cybrosys Technologies',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlSmart(String url, {String? title}) async {
    final uri = Uri.parse(url);
    try {
      if (uri.scheme == 'mailto') {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        }

        final fallback = Uri.parse('https://www.cybrosys.com/contact/');
        final fbOk = await launchUrl(
          fallback,
          mode: LaunchMode.externalApplication,
        );
        if (!fbOk) {
          final webOk = await launchUrl(
            fallback,
            mode: LaunchMode.inAppBrowserView,
          );
          if (!webOk && mounted) {
            CustomSnackbar.showError(context, 'Could not open contact page.');
          }
        }
        return;
      }

      if (uri.scheme == 'http' || uri.scheme == 'https') {
        bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
        if (!ok && mounted) {
          CustomSnackbar.showError(context, 'Could not open link.');
        }
        return;
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        CustomSnackbar.showError(
          context,
          'No app available to open this link.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, 'Could not open link. ${e.toString()}');
    }
  }

  Widget _buildSocialButton(
    BuildContext context,
    String imagePath,
    Color underlineColor,
    String label,
    VoidCallback onPressed,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              imagePath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Appearance',
                icon: HugeIcons.strokeRoundedPaintBoard,
                children: [
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return SwitchTile(
                        title: 'Dark Mode',
                        subtitle: themeProvider.isDarkMode
                            ? 'Dark theme is active'
                            : 'Light theme is active',
                        icon: themeProvider.isDarkMode
                            ? HugeIcons.strokeRoundedMoon02
                            : HugeIcons.strokeRoundedSun03,
                        value: themeProvider.isDarkMode,
                        onChanged: (value) async {
                          await themeProvider.toggleTheme();
                          if (mounted) {
                            CustomSnackbar.showSuccess(
                              context,
                              'Theme changed to ${value ? 'dark' : 'light'} mode',
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Security',
                icon: HugeIcons.strokeRoundedSecurity,
                children: [
                  SwitchTile(
                    title: 'App Lock',
                    subtitle: _authStatusDescription,
                    icon: _isBiometricAvailable
                        ? HugeIcons.strokeRoundedFingerprintScan
                        : HugeIcons.strokeRoundedLockPassword,
                    value: _isBiometricEnabled,
                    onChanged: (value) {
                      if (_isBiometricAvailable) {
                        _toggleBiometric(value);
                      } else {
                        CustomSnackbar.showError(
                          context,
                          'Biometric authentication not available on this device',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: 'Language & Region',
                icon: HugeIcons.strokeRoundedSettings02,
                headerTrailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: () async {
                    await Future.wait([
                      settingsProvider.fetchAvailableLanguages(
                        markManual: true,
                      ),
                      settingsProvider.fetchAvailableCurrencies(
                        markManual: true,
                      ),
                      settingsProvider.fetchAvailableTimezones(
                        markManual: true,
                      ),
                    ]);
                    if (mounted) {
                      CustomSnackbar.showInfo(
                        context,
                        'Language & Region refreshed',
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                ),
                children: [
                  OdooDropdownTile(
                    title: 'Language',
                    subtitle: 'Select your preferred language',
                    icon: HugeIcons.strokeRoundedTranslate,
                    selectedValue: settingsProvider.selectedLanguage,
                    options: settingsProvider.availableLanguages,
                    isLoading: settingsProvider.isLoadingLanguages,
                    onChanged: (value) async {
                      try {
                        await settingsProvider.updateLanguage(value!);
                        if (mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            'Language updated to ${settingsProvider.getLanguageDisplayName(value)}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update language: $e',
                          );
                        }
                      }
                    },
                    displayKey: 'name',
                    valueKey: 'code',
                    lastUpdated: settingsProvider.languagesUpdatedAt,
                  ),
                  OdooDropdownTile(
                    title: 'Currency',
                    subtitle: 'Default currency for transactions',
                    icon: HugeIcons.strokeRoundedDollar01,
                    selectedValue: settingsProvider.selectedCurrency,
                    options: settingsProvider.availableCurrencies,
                    isLoading: settingsProvider.isLoadingCurrencies,
                    onChanged: (value) async {
                      try {
                        await settingsProvider.updateCurrency(value!);
                        if (mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            'Currency updated to ${settingsProvider.getCurrencyDisplayName(value)}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update currency: $e',
                          );
                        }
                      }
                    },
                    displayKey: 'full_name',
                    valueKey: 'name',
                    lastUpdated: settingsProvider.currenciesUpdatedAt,
                  ),
                  OdooDropdownTile(
                    title: 'Timezone',
                    subtitle: 'Your local timezone',
                    icon: HugeIcons.strokeRoundedClock01,
                    selectedValue: settingsProvider.selectedTimezone,
                    options: settingsProvider.availableTimezones,
                    isLoading: settingsProvider.isLoadingTimezones,
                    onChanged: (value) async {
                      try {
                        await settingsProvider.updateTimezone(value!);
                        if (mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            'Timezone updated to ${settingsProvider.getTimezoneDisplayName(value)}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update timezone: $e',
                          );
                        }
                      }
                    },
                    displayKey: 'name',
                    valueKey: 'code',
                    lastUpdated: settingsProvider.timezonesUpdatedAt,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SectionCard(
                title: 'Help & Support',
                icon: HugeIcons.strokeRoundedCustomerSupport,
                children: [
                  ActionTile(
                    title: 'Odoo Help Center',
                    subtitle: 'Documentation, guides and resources',
                    icon: HugeIcons.strokeRoundedHelpCircle,
                    onTap: () => _launchUrlSmart(
                      'https://www.odoo.com/documentation',
                      title: 'Odoo Help Center',
                    ),
                  ),
                  ActionTile(
                    title: 'Odoo Support',
                    subtitle: 'Create a ticket with Odoo Support',
                    icon: HugeIcons.strokeRoundedCustomerSupport,
                    onTap: () => _launchUrlSmart(
                      'https://www.odoo.com/help',
                      title: 'Odoo Support',
                    ),
                  ),
                  ActionTile(
                    title: 'Odoo Community Forum',
                    subtitle: 'Ask the community for help',
                    icon: HugeIcons.strokeRoundedUserGroup,
                    onTap: () => _launchUrlSmart(
                      'https://www.odoo.com/forum/help-1',
                      title: 'Odoo Forum',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'About',
                icon: HugeIcons.strokeRoundedBuilding06,
                children: [_buildAboutContent(context)],
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
