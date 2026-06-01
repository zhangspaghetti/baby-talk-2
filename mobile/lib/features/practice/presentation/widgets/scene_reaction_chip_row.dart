import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class PracticeReactionOption {
  const PracticeReactionOption({
    required this.type,
    required this.label,
    required this.description,
  });

  final BabyReactionType type;
  final String label;
  final String description;
}

// ---------------------------------------------------------------------------
// Scene-specific reaction option data
// ---------------------------------------------------------------------------

/// Returns the three reaction options for [sceneTag].
///
/// Mapping per spec §6:
/// - index 0 → [BabyReactionType.engaged]  → always 「有回应」
/// - index 1 → [BabyReactionType.calm]     → scene-specific action word
/// - index 2 → [BabyReactionType.imitated] → always 「没反应」
List<PracticeReactionOption> sceneReactionOptions(String? sceneTag) {
  final String calmLabel;
  switch (sceneTag) {
    case 'feeding':
      calmLabel = '吃了一口';
      break;
    case 'drinking':
      calmLabel = '喝了一口';
      break;
    case 'diaper':
    case 'bath':
    case 'going_out':
      calmLabel = '配合了';
      break;
    case 'bedtime':
      calmLabel = '安静了';
      break;
    default:
      calmLabel = '认真听了';
  }

  return [
    PracticeReactionOption(
      type: BabyReactionType.engaged,
      label: '有回应',
      description: '宝宝有明显回应。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.calm,
      label: calmLabel,
      description: '宝宝做出具体动作。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.imitated,
      label: '没反应',
      description: '宝宝暂时没有回应。',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class SceneReactionChipRow extends StatelessWidget {
  const SceneReactionChipRow({
    super.key,
    required this.phraseId,
    required this.sceneTag,
    required this.enabled,
    required this.onSelected,
    this.selectedType,
  });

  final String phraseId;
  final String? sceneTag;
  final bool enabled;
  final ValueChanged<BabyReactionType>? onSelected;

  /// When non-null, this chip shows a checkmark and is semantically selected.
  final BabyReactionType? selectedType;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final options = sceneReactionOptions(sceneTag);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _ReactionChip(
            key: Key('reaction-$phraseId-${option.type.wireValue}'),
            option: option,
            enabled: enabled,
            isSelected: selectedType == option.type,
            colors: colors,
            onTap: (enabled && onSelected != null)
                ? () => onSelected!(option.type)
                : null,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private chip widget
// ---------------------------------------------------------------------------

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    super.key,
    required this.option,
    required this.enabled,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final PracticeReactionOption option;
  final bool enabled;
  final bool isSelected;
  final BabyTalkColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? colors.success
        : (enabled ? colors.outlineSoft : colors.textMuted);
    final textColor = enabled ? colors.textPrimary : colors.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: isSelected,
      label: option.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(9999),
              color: isSelected ? colors.successSoft : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, size: 16, color: colors.success),
                  const SizedBox(width: 4),
                ],
                Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected ? colors.success : textColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
