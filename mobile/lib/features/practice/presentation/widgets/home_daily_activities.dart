import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// A section displaying daily practice activities as horizontal icon buttons.
///
/// Shows a header "Daily Growth Activities" with a chevron, and a row
/// of three tappable activity cards (Read Together, Sing Songs, Play Talk).
class HomeDailyActivities extends StatelessWidget {
  const HomeDailyActivities({super.key, this.onActivityTap, this.onSeeAll});

  /// Called when an activity card is tapped with the activity name.
  final void Function(String activityName)? onActivityTap;

  /// Called when the section header / chevron is tapped.
  final VoidCallback? onSeeAll;

  static const List<_Activity> _activities = [
    _Activity(name: 'Read Together', icon: Icons.menu_book_rounded),
    _Activity(name: 'Sing Songs', icon: Icons.music_note_rounded),
    _Activity(name: 'Play Talk', icon: Icons.chat_bubble_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      key: const Key('home-daily-activities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(onSeeAll: onSeeAll),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        Semantics(
          label: 'Daily growth activities',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _activities.map((activity) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingXxs,
                  ),
                  child: _ActivityCard(
                    activity: activity,
                    colors: colors,
                    onTap: () => onActivityTap?.call(activity.name),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: 'See all daily growth activities',
      child: GestureDetector(
        onTap: onSeeAll,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Growth Activities',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.colors,
    required this.onTap,
  });

  final _Activity activity;
  final BabyTalkColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: activity.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: Key(
            'activity-card-${activity.name.toLowerCase().replaceAll(' ', '-')}',
          ),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(activity.icon, size: 32, color: colors.accentDark),
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Text(
                activity.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Activity {
  const _Activity({required this.name, required this.icon});

  final String name;
  final IconData icon;
}
