import 'package:flutter/material.dart';

import '../../domain/models/ritual_room_content.dart';

final class RitualContextInputTray extends StatelessWidget {
  const RitualContextInputTray({
    super.key,
    required this.prompt,
    required this.choices,
    required this.moreChoicesLabel,
    required this.onReactionSelected,
  });

  final String prompt;
  final List<RitualReactionChoice> choices;
  final String moreChoicesLabel;
  final ValueChanged<String> onReactionSelected;

  @override
  Widget build(BuildContext context) {
    final inlineChoices = choices.take(2).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < inlineChoices.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: inlineChoices[index].label,
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      key: Key('ritual-reaction-choice-$index'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          onReactionSelected(inlineChoices[index].id),
                      child: Text(
                        inlineChoices[index].label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (choices.length > 2)
            Align(
              alignment: Alignment.center,
              child: Semantics(
                label: moreChoicesLabel,
                button: true,
                container: true,
                excludeSemantics: true,
                child: TextButton(
                  key: const Key('ritual-more-reactions'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => _showAdditionalChoices(context),
                  child: Text(moreChoicesLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAdditionalChoices(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          key: const Key('ritual-reaction-sheet'),
          height: MediaQuery.sizeOf(sheetContext).height * 0.5,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    prompt,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final choice in choices.skip(2))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Semantics(
                              label: choice.label,
                              button: true,
                              container: true,
                              excludeSemantics: true,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  onReactionSelected(choice.id);
                                },
                                child: Text(choice.label),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
