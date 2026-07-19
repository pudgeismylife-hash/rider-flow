import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? trendText;
  final bool? isPositiveTrend; // true for green, false for red, null for neutral
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.primaryGold,
    this.trendText,
    this.isPositiveTrend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final trendColor = isPositiveTrend == null
        ? Colors.grey
        : (isPositiveTrend! ? AppTheme.successGreen : AppTheme.errorRed);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (trendText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositiveTrend == null
                          ? Icons.trending_flat_rounded
                          : (isPositiveTrend! ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                      size: 16,
                      color: trendColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trendText!,
                        style: TextStyle(
                          fontSize: 11,
                          color: trendColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
