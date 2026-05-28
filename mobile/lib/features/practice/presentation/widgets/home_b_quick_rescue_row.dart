import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Quick scene rescue row for Home B (Scene-mentor direction).
///
/// A horizontally scrollable row of scene chips that lets parents quickly
/// get Xiaohe's help for common urgent situations.
/// Design spec: "宝宝不肯睡", "洗澡哭了", "要出门了".
class HomeBQuickRescueRow extends StatelessWidget {
  const HomeBQuickRescueRow({
    super.key,
    this.onSceneSelected,
  });

  final void Function(String scene)? onSceneSelected;

  static const List<_RescueScene> _scenes = [
    _RescueScene(
      label: '宝宝不肯睡',
      icon: Icons.nightlight_round,
    ),
    _RescueScene(
      label: '洗澡哭了',
      icon: Icons.bubble_chart_outlined,
    ),
    _RescueScene(
      label: '要出门了',
      icon: Icons.directions_walk_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Column(
      key: const Key('home-b-quick-rescue-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '需要换个场景？',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _scenes.length,
            separatorBuilder: (a, b) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final scene = _scenes[index];
              return Semantics(
                button: true,
                label: '临时场景: ${scene.label}',
                child: GestureDetector(
                  onTap: () => onSceneSelected?.call(scene.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgSunken,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors.outlineSoft),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          scene.icon,
                          size: 16,
                          color: colors.accentDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          scene.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RescueScene {
  const _RescueScene({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
