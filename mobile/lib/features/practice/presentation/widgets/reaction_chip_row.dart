import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

/// Maps reaction types to their icon and accent color.
class _ReactionVisual {
  const _ReactionVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_ReactionVisual _visualFor(
  BabyReactionType type,
  BabyTalkColors colors,
  bool enabled,
) {
  switch (type) {
    case BabyReactionType.engaged:
      return _ReactionVisual(
        icon: Icons.sentiment_satisfied_alt_rounded,
        color: enabled ? colors.success : colors.textMuted,
      );
    case BabyReactionType.calm:
      return _ReactionVisual(
        icon: Icons.sentiment_neutral_rounded,
        color: enabled ? colors.info : colors.textMuted,
      );
    case BabyReactionType.imitated:
      return _ReactionVisual(
        icon: Icons.sentiment_dissatisfied_rounded,
        color: enabled ? colors.textMuted : colors.textMuted,
      );
    case BabyReactionType.needsBreak:
      return _ReactionVisual(
        icon: Icons.sentiment_very_dissatisfied_rounded,
        color: enabled ? colors.warning : colors.textMuted,
      );
  }
}

class ReactionChipRow extends StatelessWidget {
  const ReactionChipRow({
    super.key,
    required this.phraseId,
    required this.enabled,
    required this.onSelected,
  });

  final String phraseId;
  final bool enabled;
  final ValueChanged<BabyReactionType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in practiceReactionOptions)
          Semantics(
            button: true,
            enabled: enabled,
            child: Builder(
              builder: (context) {
                final visual = _visualFor(option.type, colors, enabled);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key(
                      'reaction-$phraseId-${option.type.wireValue}',
                    ),
                    borderRadius: BorderRadius.circular(9999),
                    onTap:
                        enabled && onSelected != null
                            ? () => onSelected!(option.type)
                            : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: enabled
                              ? colors.outlineSoft
                              : colors.textMuted,
                        ),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            visual.icon,
                            size: 18,
                            color: visual.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            option.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: enabled
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w700,
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
