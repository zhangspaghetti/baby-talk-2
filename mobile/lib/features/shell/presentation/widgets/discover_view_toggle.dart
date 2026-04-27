import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

enum DiscoverBrowseView { activity, space }

class DiscoverViewToggle extends StatelessWidget {
  const DiscoverViewToggle({
    super.key,
    required this.selectedView,
    required this.onChanged,
  });

  final DiscoverBrowseView selectedView;
  final ValueChanged<DiscoverBrowseView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-view-toggle'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: DiscoverTogglePill(
              key: const Key('discover-tab-activity'),
              label: l.discoverByActivity,
              icon: Icons.explore_outlined,
              selected: selectedView == DiscoverBrowseView.activity,
              onTap: () => onChanged(DiscoverBrowseView.activity),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DiscoverTogglePill(
              key: const Key('discover-tab-space'),
              label: l.discoverBySpace,
              icon: Icons.grid_view_rounded,
              selected: selectedView == DiscoverBrowseView.space,
              onTap: () => onChanged(DiscoverBrowseView.space),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoverTogglePill extends StatelessWidget {
  const DiscoverTogglePill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: selected ? colors.bgSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? colors.accentDark : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
