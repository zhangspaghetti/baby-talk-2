import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// 共享场景筛选 pill（组件规格 #1 ScenePill）。
///
/// 用于 Discover 的横滑筛选条等场景。token 驱动：圆角 `pillRadius`、
/// 选中态 `accent` 底 + `accentDark` 1.5px 边框、未选中 `bgSunken` 底，
/// 最小触控高度 44px，并附 `Semantics(selected:)` 语义状态以满足无障碍。
class AppScenePill extends StatelessWidget {
  const AppScenePill({
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
    return Semantics(
      label: '场景筛选: $label${isSelected ? "，已选中" : ""}',
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.accent : colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayoutConstants.spacingMd,
              vertical: AppLayoutConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
              border: isSelected
                  ? Border.all(color: colors.accentDark, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
