import 'package:flutter/material.dart';

import '../../../../app/theme/ritual_room_theme.dart';
import '../../domain/models/ritual_room_content.dart';

final class RitualContextChoices extends StatelessWidget {
  const RitualContextChoices({
    super.key,
    required this.choices,
    required this.enabled,
    required this.selectedReactionId,
    required this.onSelected,
  });

  final List<RitualReactionChoice> choices;
  final bool enabled;
  final String? selectedReactionId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final choice in choices)
          OutlinedButton(
            key: Key('ritual-context-choice-${choice.id}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              backgroundColor: selectedReactionId == choice.id
                  ? ritualTheme.assistiveSurface
                  : ritualTheme.canvas,
              foregroundColor: selectedReactionId == choice.id
                  ? ritualTheme.assistive
                  : ritualTheme.textPrimary,
              elevation: 0,
              side: BorderSide(
                color: selectedReactionId == choice.id
                    ? ritualTheme.assistive
                    : ritualTheme.divider.withValues(alpha: 0.5),
                width: selectedReactionId == choice.id ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: TextStyle(
                fontSize: 15,
                height: 1.2,
                letterSpacing: 0.1,
                fontWeight: selectedReactionId == choice.id
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
            onPressed: enabled ? () => onSelected(choice.id) : null,
            child: Text(choice.label, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
