import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';

class SceneButton extends StatelessWidget {
  const SceneButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return AppScaleButton(
      scaleDown: 0.95,
      onTap: () {
        AppHaptics.lightTap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.outlineSoft,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected ? colors.warmShadowSm : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
