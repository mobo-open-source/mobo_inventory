import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../features/company/widgets/company_selector_widget.dart';
import '../../features/company/providers/company_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/feature_refresh_helper.dart';
import '../../shared/widgets/odoo_avatar.dart';

/// A collection of widgets for the AppBar that handle company selection and profile navigation.
class AppBarProfileActions extends StatelessWidget {
  const AppBarProfileActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompanySelectorWidget(
          onCompanyChanged: () async {
            if (!context.mounted) return;
            final provider = context.read<CompanyProvider>();
            final companyName =
                provider.selectedCompany?['name']?.toString() ?? 'company';

            await context.read<ProfileProvider>().fetchUserProfile(
              forceRefresh: true,
            );

            if (context.mounted) {
              CustomSnackbar.showSuccess(context, 'Switched to $companyName');

              await FeatureRefreshHelper.refreshAll(context);
            }
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              final userAvatarBase64 = profileProvider.userAvatarBase64;

              return IconButton(
                icon: OdooAvatar(
                  key: ValueKey(
                    'avatar_${userAvatarBase64 != null ? "image" : "placeholder"}',
                  ),
                  imageBase64: userAvatarBase64,
                  size: 32,
                  iconSize: 18,
                  borderRadius: BorderRadius.circular(16),
                  placeholderColor: isDark
                      ? Colors.grey[800]
                      : Colors.grey[300],
                  iconColor: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: () {
                  context.pushNamed(AppRoutes.profile).then((_) {
                    if (context.mounted) {
                      context.read<ProfileProvider>().fetchUserProfile(
                        forceRefresh: true,
                      );
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
