import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// A segmented-control tab button designed to sit inside a [bgSunken] pill
/// container (one per [Expanded] in a [Row]).
///
/// Selected state animates the surface in, lifts it with a warm shadow, and
/// bumps the label weight. Accessible by default: exposes `button` + `selected`
/// semantics. Pass [semanticsLabel] to override the announced label.
class AppSegmentTab extends StatelessWidget {
  const AppSegmentTab({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Optional custom semantics label (defaults to [label]).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(
            minHeight: AppLayoutConstants.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppLayoutConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppLayoutConstants.spacingSm),
            boxShadow: isSelected ? colors.warmShadowSm : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isSelected ? colors.textPrimary : colors.textMuted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
