import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/biometric_context_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../core/routing/app_routes.dart';
import '../../login/pages/totp_page.dart';
import '../../../shared/widgets/odoo_avatar.dart';
import '../../../core/utils/clear_providers.dart';

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
            .where(
              (account) =>
                  !_isCurrentAccount(account, sessionService) &&
                  account['serverUrl'] ==
                      sessionService.currentSession?.serverUrl,
            )
            .toList();

        final accountCount = otherAccounts.length;

        return ExpansionTile(
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
            ? (isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50])
            : (isDark ? Colors.grey[800] : Colors.grey[50]),
        border: Border.all(
          color: isCurrent
              ? (isDark ? Colors.blue[700]! : Colors.blue[300]!)
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[700] : Colors.blue[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Current',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
                    color: Colors.orange[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Needs re-authentication',
                    style: TextStyle(
                      color: Colors.orange[600],
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
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 18,
                ),
                onSelected: (value) async {
                  if (value == 'remove') {
                    await _removeAccount(context, account, sessionService);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
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
        label: const Text('Add Account'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
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
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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

          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: serverUrl,
                database: account['database'],
                username: username ?? '',
                password: account['password'] ?? '',
                protocol: protocol,
              ),
            ),
          );
          if (result == true) {
            if (context.mounted) {
              resetAllAppProviders(context);
              context.goNamed(AppRoutes.app);
            }
          }
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

    try {
      String? password;
      final username =
          account['username']?.toString() ?? account['userName']?.toString();

      if (account.containsKey('sessionId')) {
        try {
          final success = await OdooSessionManager.loginAndSaveSession(
            serverUrl: account['serverUrl'],
            database: account['database'],
            userLogin: username ?? '',
            password: account['password'] ?? '',
            sessionId: account['sessionId'],
          );
          if (success) {
            if (context.mounted) {
              Navigator.pop(context);
              resetAllAppProviders(context);
              context.goNamed(AppRoutes.app);
              biometricContext.endAccountOperation('account_switch');
            }
            return;
          }
        } catch (e) {
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('two-factor') ||
              errorMsg.contains('totp') ||
              errorMsg.contains('token_expired') ||
              (errorMsg.contains('null') && errorMsg.contains('subtype'))) {
            rethrow;
          }
        }
      }

      password = await sessionService.retrievePasswordWithMultiplePatterns(
        account,
      );

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
        if (context.mounted) {
          Navigator.pop(context);
          resetAllAppProviders(context);
          context.goNamed(AppRoutes.app);
          biometricContext.endAccountOperation('account_switch');
        }
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
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
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 24,
                color: Colors.red.shade400,
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Account',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${account['userName']} from your saved accounts?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
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
