import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in practiceReactionOptions)
          Semantics(
            button: true,
            enabled: enabled,
            child: OutlinedButton(
              key: Key('reaction-$phraseId-${option.type.wireValue}'),
              onPressed: enabled && onSelected != null
                  ? () => onSelected!(option.type)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(112, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                side: BorderSide(
                  color: enabled ? AppTheme.english : AppTheme.textMuted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
