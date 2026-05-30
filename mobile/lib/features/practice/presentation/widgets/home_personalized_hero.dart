import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomePersonalizedHero extends StatelessWidget {
  const HomePersonalizedHero({
    super.key,
    required this.snapshot,
    required this.stageMatch,
    required this.starterPhrase,
    required this.activitySceneTag,
  });

  final OnboardingSnapshot snapshot;
  final StageMatch? stageMatch;
  final PracticePhrase? starterPhrase;
  final String? activitySceneTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                key: const Key('home-stage-pill'),
                label: Text(stageMatch?.title ?? snapshot.ageBucket.label),
              ),
              if (activitySceneTag != null &&
                  activitySceneTag!.trim().isNotEmpty)
                Chip(label: Text(activitySceneTag!)),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          Text(
            l.homePersonalizedHeading(snapshot.childDisplayName),
            key: const Key('personalized-home-heading'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            stageMatch?.summary ?? l.homeDefaultStageSummary,
            key: const Key('personalized-home-stage-summary'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          Container(
            key: starterPhrase != null
                ? const Key('home-starter-seed')
                : const Key('home-starter-seed-loading'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
            decoration: BoxDecoration(
              color: colors.englishSoft,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.largeRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeFirstSeed, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                Text(
                  starterPhrase?.english ?? 'Bath time, baby.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.english,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(
                  starterPhrase?.chinese ?? l.homeStartBathTime,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          Container(
            key: const Key('home-daily-phrase-cue'),
            width: double.infinity,
            padding: AppLayoutConstants.bannerPadding,
            decoration: BoxDecoration(
              color: colors.bgAccentSoft,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.cardRadius,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color: colors.accentDark,
                  size: AppLayoutConstants.iconSizeMd,
                ),
                const SizedBox(width: AppLayoutConstants.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeDailyPhraseCueLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.accentDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingXs),
                      Text(
                        l.homeDailyPhraseCueBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
