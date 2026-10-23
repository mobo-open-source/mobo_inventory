import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../core/services/inventory_access_service.dart';
import '../../../core/utils/module_missing_dialog.dart';
import '../../../shared/widgets/dialogs/access_denied_dialog.dart';
import '../../../shared/widgets/dialogs/common_dialog.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../core/routing/app_routes.dart';
import '../../login/pages/login_layout.dart'
    show DatabaseExpiry, DatabaseExpiredException;
import '../../login/pages/totp_page.dart';
import '../../../shared/widgets/odoo_avatar.dart';

class SwitchAccountWidget extends StatelessWidget {
  const SwitchAccountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        final otherAccounts = sessionService.storedAccounts
            .where((account) => !_isCurrentAccount(account, sessionService))
            .toList();

        final accountCount = otherAccounts.length;

        return ExpansionTile(
          // ExpansionTile otherwise falls back to a Border with top/bottom
          // sides in theme.dividerColor once expanded, which reads as a dark
          // line cutting between the header and the account list.
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(HugeIcons.strokeRoundedUserSwitch, color: iconColor),
          title: const Text(
            'Switch Accounts',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            accountCount > 0
                ? '$accountCount other account${accountCount != 1 ? 's' : ''} available'
                : 'Add multiple accounts to switch quickly',
            style: TextStyle(color: subtitleColor),
          ),
          children: [
            if (accountCount == 0)
              _buildEmptyState(context, sessionService)
            else
              ...otherAccounts.map(
                (account) => _buildAccountTile(
                  context,
                  account,
                  sessionService,
                  isCurrent: false,
                ),
              ),
            _buildAddAccountButton(context),
          ],
        );
      },
    );
  }

  bool _isCurrentAccount(
    Map<String, dynamic> account,
    SessionService sessionService,
  ) {
    final currentSession = sessionService.currentSession;
    if (currentSession == null) return false;

    return account['userId']?.toString() == currentSession.userId.toString() &&
        account['serverUrl'] == currentSession.serverUrl &&
        account['database'] == currentSession.database;
  }

  Widget _buildEmptyState(BuildContext context, SessionService sessionService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              HugeIcons.strokeRoundedUserAdd01,
              size: 30,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Other Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add multiple accounts to switch between them quickly',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService, {
    required bool isCurrent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isCurrent
            ? (isDark
                  ? StatusColors.backgroundDark(StatusColors.blue)
                  : StatusColors.backgroundLight(StatusColors.blue))
            : (isDark ? Colors.grey[800] : Colors.grey[50]),
        border: Border.all(
          color: isCurrent
              ? StatusColors.blue
              : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildUserAvatar(account, isCurrent, isDark),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account['userName'] ?? 'Unknown User',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isCurrent)
              StatusColors.buildStatusBadge(
                'Current',
                StatusColors.blue,
                isDark: isDark,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              account['database'] ?? 'Unknown Database',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (!isCurrent &&
                (account['needsReauth']?.toString() == 'true' ||
                    account['password']?.toString().isEmpty == true))
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: StatusColors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Needs re-authentication',
                    style: TextStyle(
                      color: StatusColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: isCurrent
            ? null
            : PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
                onSelected: (value) async {
                  if (value == 'remove') {
                    await _removeAccount(context, account, sessionService);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
        onTap: isCurrent
            ? null
            : () async {
                await _switchAccount(context, account, sessionService);
              },
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          final sessionService = Provider.of<SessionService>(
            context,
            listen: false,
          );
          final current = sessionService.currentSession;

          context.pushNamed(
            AppRoutes.serverSetup,
            extra: {
              'url': current?.serverUrl ?? '',
              'database': current?.database ?? '',
              'isAddingAccount': true,
            },
          );
        },
        icon: const Icon(HugeIcons.strokeRoundedUserAdd01, size: 18),
        label: const Text(
          'Add Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final needsReauth = account['needsReauth']?.toString() == 'true';
    final hasEmptyPassword = account['password']?.toString().isEmpty == true;

    if (needsReauth || hasEmptyPassword) {
      context.pushNamed(
        AppRoutes.login,
        extra: {
          'url': account['serverUrl'] ?? '',
          'database': account['database'] ?? '',
          'prefilledUsername': account['username'] ?? account['userName'],
        },
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                'Switching Account...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await _performDirectAccountSwitch(context, account, sessionService);
    } on DatabaseExpiredException {
      if (context.mounted) {
        Navigator.pop(context);
        // The switch was rolled back, so the user stays on the account they
        // were already using.
        await DatabaseExpiry.showExpiredDialog(context);
      }
    } on InventoryModuleMissingException {
      if (context.mounted) {
        Navigator.pop(context);
        // 'OK', not 'Back to Login': the switch was rolled back, so the user
        // stays signed in on the account they were already using — there is
        // no login screen for this button to send them to.
        await showModuleMissingDialog(context, actionLabel: 'OK');
      }
    } on InventoryAccessDeniedException catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        showAccessDeniedDialog(context, message: e.message);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);

        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('two-factor') ||
            errorMsg.contains('totp') ||
            errorMsg.contains('2fa') || // Added 2fa check for parity
            errorMsg.contains('token_expired') ||
            (errorMsg.contains('null') && errorMsg.contains('subtype'))) {
          final username =
              account['username']?.toString() ??
              account['userName']?.toString();

          final serverUrl = account['serverUrl']?.toString() ?? '';
          String protocol = 'https://';
          if (serverUrl.startsWith('http://')) {
            protocol = 'http://';
          }

          // From secure storage, not the account map (which never holds
          // one): the 2FA page signs in with the password first, and an
          // empty one is refused before a code is ever asked for.
          final password =
              await sessionService.retrievePasswordWithMultiplePatterns(
                account,
              ) ??
              '';
          if (!context.mounted) return;

          // TotpPage resets providers and navigates into the app itself once
          // the code is verified, replacing the whole stack, so there is
          // nothing left to do here on success.
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: serverUrl,
                database: account['database'],
                username: username ?? '',
                password: password,
                protocol: protocol,
                isAddingAccount: true,
              ),
            ),
          );
          return;
        }

        if (errorMsg.contains('authentication') ||
            errorMsg.contains('password') ||
            errorMsg.contains('credentials')) {
          context.pushNamed(
            AppRoutes.login,
            extra: {
              'url': account['serverUrl'] ?? '',
              'database': account['database'] ?? '',
              'prefilledUsername': account['username'] ?? account['userName'],
            },
          );
        } else {
          _showErrorDialog(
            context,
            'Switch Failed',
            _parseAccountSwitchError(e.toString()),
          );
        }
      }
    }
  }

  Widget _buildUserAvatar(
    Map<String, dynamic> account,
    bool isCurrent,
    bool isDark,
  ) {
    final serverUrl = account['serverUrl'] as String?;
    final userId = account['userId'];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarImage(serverUrl, userId, isCurrent, isDark, account),
      ),
    );
  }

  Widget _buildAvatarImage(
    String? serverUrl,
    dynamic userId,
    bool isCurrent,
    bool isDark, [
    Map<String, dynamic>? account,
  ]) {
    final imageBase64 = account != null
        ? account['imageBase64'] as String?
        : null;

    if (imageBase64 != null &&
        imageBase64.isNotEmpty &&
        imageBase64 != 'false') {
      return OdooAvatar(
        imageBase64: imageBase64,
        size: 40.0,
        iconSize: 20.0,
        placeholderColor: isDark ? Colors.grey[700] : Colors.grey[100],
        iconColor: isDark ? Colors.grey[400] : Colors.grey[600],
      );
    }

    if (serverUrl == null || userId == null) {
      return _buildDefaultAvatar(isCurrent, isDark, account);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final avatarUrl =
        '$serverUrl/web/image?model=res.users&id=$userId&field=image_128&unique=$timestamp';

    return CachedNetworkImage(
      imageUrl: avatarUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) {
        return Container(
          color: isDark ? Colors.grey[700] : Colors.grey[100],
          child: Icon(
            HugeIcons.strokeRoundedUser,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        );
      },
      errorWidget: (context, url, error) {
        return _buildDefaultAvatar(isCurrent, isDark, account);
      },
    );
  }

  Future<void> _performDirectAccountSwitch(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final biometricContext = BiometricContextService();
    biometricContext.startAccountOperation('account_switch');

    // Captured before any switch attempt so a failure below can restore
    // exactly the account that was active, rather than leaving a
    // half-switched session as the current one.
    final previousSession = sessionService.currentSession;

    // The account being switched to is held in memory only until it has
    // passed the checks below, so one this app refuses is never written to
    // the device in place of the account the user is still signed in to.
    OdooSessionManager.beginProvisionalSession();

    // An expired database is refused before anything else: none of it is
    // usable, whatever modules or access rights it has. Module is checked
    // next: a server missing Inventory is always reported as that, rather
    // than blamed on the user's own access rights. Portal access is only
    // checked once the module is confirmed present.
    Future<void> enforceAccessOrThrow() async {
      if (await DatabaseExpiry.isCurrentSessionExpired()) {
        await OdooSessionManager.discardProvisionalSession(previousSession);
        throw const DatabaseExpiredException();
      }
      final accessService = InventoryAccessService();
      final inventoryInstalled =
          await accessService.isInventoryModuleInstalled();
      if (!inventoryInstalled) {
        await OdooSessionManager.discardProvisionalSession(previousSession);
        throw const InventoryModuleMissingException();
      }
      final isPortal = await accessService.isPortalUser();
      if (isPortal) {
        await OdooSessionManager.discardProvisionalSession(previousSession);
        throw const InventoryAccessDeniedException(
          InventoryAccessService.portalUserMessage,
        );
      }
      await OdooSessionManager.commitProvisionalSession();
    }

    try {
      final username =
          account['username']?.toString() ?? account['userName']?.toString();

      // Read up front, not only for the password fallback below: the saved
      // account map never holds a password (it lives in secure storage), so
      // passing `account['password']` into the session-id restore handed the
      // session an empty password — which then wiped the saved one and made
      // the switched-to account unable to survive a restart or a re-auth.
      final password = await sessionService
          .retrievePasswordWithMultiplePatterns(account);

      if (account.containsKey('sessionId')) {
        try {
          final success = await OdooSessionManager.loginAndSaveSession(
            serverUrl: account['serverUrl'],
            database: account['database'],
            userLogin: username ?? '',
            password: password ?? '',
            sessionId: account['sessionId'],
          );
          if (success) {
            await enforceAccessOrThrow();
            if (context.mounted) {
              Navigator.pop(context);
              // Providers are reset by AccountChangeListener the moment the
              // switched-to account is committed.
              context.goNamed(AppRoutes.app);
              biometricContext.endAccountOperation('account_switch');
            }
            return;
          }
        } catch (e) {
          if (e is DatabaseExpiredException ||
              e is InventoryModuleMissingException ||
              e is InventoryAccessDeniedException) {
            rethrow;
          }
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('two-factor') ||
              errorMsg.contains('totp') ||
              errorMsg.contains('token_expired') ||
              (errorMsg.contains('null') && errorMsg.contains('subtype'))) {
            rethrow;
          }
        }
      }

      if (password == null || password.isEmpty) {
        throw Exception('No password found for account');
      }

      final success = await OdooSessionManager.loginAndSaveSession(
        serverUrl: account['serverUrl'],
        database: account['database'],
        userLogin: username ?? '',
        password: password,
      );

      if (success) {
        await enforceAccessOrThrow();
        if (context.mounted) {
          Navigator.pop(context);
          // Providers are reset by AccountChangeListener the moment the
          // switched-to account is committed.
          context.goNamed(AppRoutes.app);
          biometricContext.endAccountOperation('account_switch');
        }
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
      // Covers every way out that isn't a completed switch — a refused
      // password, an unreachable server, the 2FA hand-off — so the account
      // the user is still signed in to is the one left active, and the
      // half-finished attempt is never written to the device. A no-op if
      // the session was already committed.
      await OdooSessionManager.discardProvisionalSession(previousSession);
      biometricContext.endAccountOperation('account_switch');
      rethrow;
    }
  }

  String _parseAccountSwitchError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('access denied') ||
        errorLower.contains('invalid login') ||
        errorLower.contains('authentication failed') ||
        errorLower.contains('wrong login/password') ||
        errorLower.contains('invalid username or password') ||
        errorLower.contains('login failed')) {
      return 'Authentication failed. This account may need re-authentication.';
    }

    if (errorLower.contains('database') && errorLower.contains('not found')) {
      return 'Database not found. Please check your server configuration.';
    }

    if (errorLower.contains('connection') ||
        errorLower.contains('network') ||
        errorLower.contains('timeout') ||
        errorLower.contains('unreachable')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }

    if (errorLower.contains('500') ||
        errorLower.contains('internal server error')) {
      return 'Server error occurred. Please try again later.';
    }

    if (errorLower.contains('permission') || errorLower.contains('access')) {
      return 'Access denied. Please check your user permissions.';
    }

    return 'Failed to switch account. Please try again or re-add this account.';
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: StatusColors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 24,
                color: StatusColors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAccount(
    BuildContext context,
    Map<String, dynamic> account,
    SessionService sessionService,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // final confirmed = await showDialog<bool>(
    //   context: context,
    //   builder: (ctx) => AlertDialog(
    //     backgroundColor: isDark ? Colors.grey[900] : Colors.white,
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    //     title: Text(
    //       'Remove Account',
    //       style: TextStyle(
    //         fontWeight: FontWeight.w600,
    //         color: isDark ? Colors.white : Colors.black87,
    //       ),
    //     ),
    //     content: Text(
    //       'Are you sure you want to remove ${account['userName']} from your saved accounts?',
    //       style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
    //     ),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(ctx, false),
    //         child: Text(
    //           'Cancel',
    //           style: TextStyle(
    //             color: isDark ? Colors.grey[400] : Colors.grey[600],
    //           ),
    //         ),
    //       ),
    //       ElevatedButton(
    //         onPressed: () => Navigator.pop(ctx, true),
    //         style: ElevatedButton.styleFrom(
    //           backgroundColor: Colors.red[600],
    //           foregroundColor: Colors.white,
    //         ),
    //         child: const Text('Remove'),
    //       ),
    //     ],
    //   ),
    // );
    final confirmed = await CommonDialog.confirm(
      context,
      title: 'Remove Account',
      message:
      'Are you sure you want to remove ${account['userName']} from your saved accounts?',
      confirmText: 'Remove',
      cancelText: 'Cancel',

    );

    if (confirmed == true) {
      final accountIndex = sessionService.storedAccounts.indexWhere(
        (stored) => stored['userId'] == account['userId'],
      );

      if (accountIndex != -1) {
        await sessionService.removeStoredAccount(accountIndex);
        if (context.mounted) {
          CustomSnackbar.show(
            context: context,
            title: 'Success',
            message: 'Account ${account['userName']} removed',
            type: SnackbarType.success,
          );
        }
      }
    }
  }

  Widget _buildDefaultAvatar(
    bool isCurrent,
    bool isDark, [
    Map<String, dynamic>? account,
  ]) {
    final userName = account?['userName'] as String?;
    if (userName != null && userName.isNotEmpty) {
      final initials = _getUserInitials(userName);
      return Container(
        color: isDark ? Colors.grey[700] : Colors.grey[100],
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
      );
    }

    return Container(
      color: isDark ? Colors.grey[700] : Colors.grey[100],
      child: Icon(
        HugeIcons.strokeRoundedUser,
        size: 20,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  String _getUserInitials(String userName) {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }
}
