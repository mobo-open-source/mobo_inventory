import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/odoo_avatar.dart';

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String? jobFunction;
  final String? avatarBase64;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onTap;
  final bool showCameraButton;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.email,
    this.jobFunction,
    this.avatarBase64,
    this.onCameraPressed,
    this.onTap,
    this.showCameraButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double rs(double size) {
      final w = MediaQuery.of(context).size.width;
      final scale = (w / 390.0).clamp(0.85, 1.2);
      return size * scale;
    }

    final content = Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                    ),
                    child: OdooAvatar(
                      imageBase64: avatarBase64,
                      size: 68,
                      iconSize: 30,
                      placeholderColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      iconColor: isDark ? Colors.grey[500] : Colors.grey[600],
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                ),
                if (showCameraButton && onCameraPressed != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: onCameraPressed,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          HugeIcons.strokeRoundedCamera02,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: rs(18),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: rs(14),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.7,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                HugeIcons.strokeRoundedArrowRight01,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}
