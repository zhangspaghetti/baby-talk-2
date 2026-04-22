import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class QuickSelectCard extends StatelessWidget {
  const QuickSelectCard({
    super.key,
    required this.label,
    required this.caption,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colors.bgAccentSoft : colors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? colors.accent : colors.outlineSoft,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected ? colors.warmShadowSm : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
