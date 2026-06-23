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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices)
          OutlinedButton(
            key: Key('ritual-context-choice-${choice.id}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: selectedReactionId == choice.id
                  ? ritualTheme.assistiveSurface
                  : null,
              foregroundColor: ritualTheme.textPrimary,
              side: BorderSide(
                color: selectedReactionId == choice.id
                    ? ritualTheme.assistive
                    : ritualTheme.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: enabled ? () => onSelected(choice.id) : null,
            child: Text(choice.label, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
