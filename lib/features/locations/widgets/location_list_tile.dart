import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/location_model.dart';

class LocationListTile extends StatelessWidget {
  final StockLocation location;
  final bool isDark;
  final VoidCallback? onTap;

  const LocationListTile({
    super.key,
    required this.location,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: StatusColors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on,
                  color: isDark ? StatusColors.infoIcon : StatusColors.blue,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.completeName ?? location.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(location.usage.toUpperCase(), isDark, theme),
                      if (location.parentName != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Parent: ${location.parentName!}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? theme.primaryColor.withValues(alpha: 0.18)
            : AppTheme.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : theme.primaryColor,
        ),
      ),
    );
  }
}
