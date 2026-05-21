import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

class ActivationFrame extends StatelessWidget {
  const ActivationFrame({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l = AppLocalizations.of(context)!;
    return Semantics(
      label: l.activationFrameLabel,
      container: true,
      child: Container(
        key: const Key('activation-frame'),
        padding: AppLayoutConstants.bannerPadding,
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
          border: Border.all(
            color: colors.english.withValues(alpha: 0.32),
            width: 2,
          ),
          boxShadow: colors.warmShadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.practiceActivationKicker,
              key: const Key('practice-activation-kicker'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.accentDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppLayoutConstants.spacingXs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingSm,
                    vertical: AppLayoutConstants.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
                  ),
                  child: Text(
                    stepLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppLayoutConstants.spacingSm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutConstants.spacingMd),
            child,
          ],
        ),
      ),
    );
  }
}
