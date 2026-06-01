import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';

class ReactionButton extends StatelessWidget {
  const ReactionButton({
    super.key,
    required this.reaction,
    required this.onTap,
  });

  final BabyReaction reaction;
  final VoidCallback onTap;

  Color _backgroundColor(BabyTalkColors colors) {
    switch (reaction) {
      case BabyReaction.responded:
        return colors.successSoft;
      case BabyReaction.calmed:
        return colors.infoSoft;
      case BabyReaction.noResponse:
        return colors.bgSunken;
    }
  }

  Color _textColor(BabyTalkColors colors) {
    switch (reaction) {
      case BabyReaction.responded:
        return colors.success;
      case BabyReaction.calmed:
        return colors.info;
      case BabyReaction.noResponse:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return AppScaleButton(
      scaleDown: 0.95,
      onTap: () {
        AppHaptics.lightTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _backgroundColor(colors),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              reaction.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _textColor(colors),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
