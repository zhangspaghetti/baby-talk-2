import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

class MentorBubble extends StatelessWidget {
  const MentorBubble({
    super.key,
    required this.message,
    this.caption,
    this.trailing,
  });

  final String message;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l.onboardingMentorMessageSemantics(message),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.bgAccentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                l.onboardingMentorCaption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppLayoutConstants.spacingSm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                border: Border.all(color: colors.outlineSoft),
                boxShadow: colors.warmShadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (caption != null) ...[
                          Text(
                            caption!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.accentDark,
                            ),
                          ),
                          const SizedBox(height: AppLayoutConstants.spacingXs),
                        ],
                        Text(
                          message,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: AppLayoutConstants.spacingSm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
