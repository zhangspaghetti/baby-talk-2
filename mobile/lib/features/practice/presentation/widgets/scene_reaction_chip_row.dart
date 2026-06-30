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

/// Returns the canonical reaction options for [sceneTag].
List<PracticeReactionOption> sceneReactionOptions(String? sceneTag) {
  return const [
    PracticeReactionOption(
      type: BabyReactionType.cooperating,
      label: '配合',
      description: '宝宝有明显回应。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.hesitant,
      label: '犹豫',
      description: '宝宝有点犹豫，还在观察。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.resisting,
      label: '不想',
      description: '宝宝现在不太想继续。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.noResponse,
      label: '没反应',
      description: '宝宝暂时没有回应。',
    ),
    PracticeReactionOption(
      type: BabyReactionType.other,
      label: '其他',
      description: '这次反应不属于前面的几类。',
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
