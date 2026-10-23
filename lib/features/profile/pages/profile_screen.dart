import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/logout_view_model.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../providers/profile_provider.dart';

import 'package:mobo_inv_app/features/profile/widgets/profile_header_card.dart';
import 'package:mobo_inv_app/features/profile/widgets/switch_account_widget.dart';
import '../../../shared/widgets/action_tile.dart';
import '../../../shared/widgets/connection_status_widget.dart';

/// A screen that provides a high-level overview of the user's profile and app configuration.
///
/// This screen serves as a central hub for accessing settings, switching accounts,
/// managing profile photos, and initiating logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().initialize();
    });
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final base64Image = base64Encode(bytes);
      await context.read<ProfileProvider>().updateProfileImage(base64Image);

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          title: 'Success',
          message: 'Profile image updated successfully',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          title: 'Error',
          message: 'Failed to update image: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          InkWell(
            onTap: () {
              context.pop();
              _pickImageFromSource(ImageSource.camera);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    HugeIcons.strokeRoundedCamera02,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text('Take Photo', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          InkWell(
            onTap: () {
              context.pop();
              _pickImageFromSource(ImageSource.gallery);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    HugeIcons.strokeRoundedImageCrop,
                    size: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double rs(double size) {
      final w = MediaQuery.of(context).size.width;
      final scale = (w / 390.0).clamp(0.85, 1.2);
      return size * scale;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            fontSize: rs(22),
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.hasInternet) {
            return _buildLoadingShimmer(isDark);
          }

          if (provider.userData == null) {
            return ConnectionStatusWidget(
              serverUnreachable: true,
              onRetry: () => provider.fetchUserProfile(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchUserProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ProfileHeaderCard(
                    name:
                        provider.userData!['name']?.toString() ??
                        'Unknown User',
                    email: provider.normalizeForEdit(
                      provider.userData!['email'],
                    ),
                    jobFunction: provider.normalizeForEdit(
                      provider.userData!['function'],
                    ),
                    avatarBase64: provider.userAvatarBase64,
                    onCameraPressed: _showImageSourceActionSheet,
                    showCameraButton: false,
                    onTap: () => context.pushNamed(AppRoutes.profileDetail),
                  ),
                  const SizedBox(height: 12),

                  _buildQuickActionsSection(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: AppTheme.cardDecoration(isDark),
      child: Column(
        children: [
          ActionTile(
            title: 'Settings',
            subtitle: 'App preferences and sync options',
            icon: HugeIcons.strokeRoundedSettings01,
            onTap: () async {
              try {
                await context.pushNamed(AppRoutes.settings);
              } catch (_) {}
            },
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          const SwitchAccountWidget(),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),

          Builder(
            builder: (outerCtx) => ChangeNotifierProvider<LogoutViewModel>(
              create: (_) => LogoutViewModel(),
              child: Builder(
                builder: (ctx) => ActionTile(
                  title: 'Logout',
                  subtitle: 'Sign out from this device',
                  icon: HugeIcons.strokeRoundedLogout01,
                  trailing: const SizedBox.shrink(),
                  onTap: () => ctx.read<LogoutViewModel>().confirmLogout(ctx),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final placeholderColor = isDark ? Colors.grey[900]! : Colors.white;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: placeholderColor,
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 18,
                          width: 180,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 14,
                          width: 160,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: List.generate(2, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == 1 ? 0 : 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: 120,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: placeholderColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Container(
                                height: 12,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: placeholderColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
