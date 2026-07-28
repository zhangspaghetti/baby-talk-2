import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// A warm card showing the user's garden status for the current week.
///
/// Displays the week number, growth stage, new words planted, and a
/// motivational message to encourage continued engagement.
class HomeGardenCard extends StatelessWidget {
  const HomeGardenCard({
    super.key,
    required this.weekNumber,
    required this.stageName,
    required this.wordsPlanted,
    this.motivationalText,
  });

  /// Current week number (e.g. 3).
  final int weekNumber;

  /// Name of the current growth stage (e.g. "Seedling").
  final String stageName;

  /// Number of new words planted this week.
  final int wordsPlanted;

  /// Optional custom motivational message; falls back to the default text.
  final String? motivationalText;

  static const _defaultMotivationalText =
      'Just like your little one, the garden grows with every shared moment and word.';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: const Key('home-garden-card'),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(AppLayoutConstants.mediumRadius),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Garden: Week $weekNumber - $stageName',
            key: const Key('home-garden-card-title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
          Text(
            'New words planted this week: $wordsPlanted',
            key: const Key('home-garden-card-subtitle'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Divider(color: colors.outlineSoft, height: 1),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            motivationalText ?? _defaultMotivationalText,
            key: const Key('home-garden-card-motivational'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
