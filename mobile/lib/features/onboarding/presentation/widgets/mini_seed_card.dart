import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

class MiniSeedCard extends StatelessWidget {
  const MiniSeedCard({super.key, required this.english, required this.chinese});

  final String english;
  final String chinese;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l.onboardingMiniSeedCardSemantics(english),
      child: ExcludeSemantics(
        child: Container(
          key: const Key('onboarding-mini-seed-card'),
          width: double.infinity,
          padding: AppLayoutConstants.bannerPadding,
          decoration: BoxDecoration(
            color: colors.englishSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
            border: Border.all(color: colors.info),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('onboarding-mini-seed-play-mark'),
                width: AppLayoutConstants.minTouchTarget,
                height: AppLayoutConstants.minTouchTarget,
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.play_arrow_rounded, color: colors.info),
              ),
              const SizedBox(width: AppLayoutConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.onboardingFirstSeed,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.info,
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingXs),
                    Text(
                      english,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 24,
                        height: 1.3,
                        color: colors.english,
                      ),
                    ),
                    if (chinese.trim().isNotEmpty) ...[
                      const SizedBox(height: AppLayoutConstants.spacingXs),
                      Text(
                        chinese,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
