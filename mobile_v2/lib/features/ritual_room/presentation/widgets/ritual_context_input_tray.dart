import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/ritual_room_content.dart';

final class RitualContextInputTray extends StatefulWidget {
  const RitualContextInputTray({
    super.key,
    required this.prompt,
    required this.choices,
    required this.moreChoicesLabel,
    required this.onReactionSelected,
    this.enabled = true,
    this.selectedReactionId,
  });

  final String prompt;
  final List<RitualReactionChoice> choices;
  final String moreChoicesLabel;
  final ValueChanged<String> onReactionSelected;
  final bool enabled;
  final String? selectedReactionId;

  @override
  State<RitualContextInputTray> createState() => _RitualContextInputTrayState();
}

final class _RitualContextInputTrayState extends State<RitualContextInputTray> {
  late final ValueNotifier<_ReactionControlProjection> _projection;
  var _sheetOpen = false;
  var _projectionDisposed = false;

  @override
  void initState() {
    super.initState();
    _projection = ValueNotifier<_ReactionControlProjection>(
      _ReactionControlProjection(
        enabled: widget.enabled,
        selectedReactionId: widget.selectedReactionId,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RitualContextInputTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publishProjection(
      enabled: widget.enabled,
      selectedReactionId: widget.selectedReactionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inlineChoices = widget.choices.take(2).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.prompt,
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
                    enabled: widget.enabled,
                    selected:
                        widget.selectedReactionId == inlineChoices[index].id,
                    container: true,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      key: Key('ritual-reaction-choice-$index'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: widget.enabled
                          ? () => _dispatchReaction(inlineChoices[index].id)
                          : null,
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
          if (widget.choices.length > 2)
            Align(
              alignment: Alignment.center,
              child: Semantics(
                label: widget.moreChoicesLabel,
                button: true,
                enabled: widget.enabled,
                container: true,
                excludeSemantics: true,
                child: TextButton(
                  key: const Key('ritual-more-reactions'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: widget.enabled && !_sheetOpen
                      ? () => _showAdditionalChoices(context)
                      : null,
                  child: Text(widget.moreChoicesLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAdditionalChoices(BuildContext context) {
    if (_sheetOpen || !_projection.value.enabled) {
      return Future<void>.value();
    }
    _sheetOpen = true;
    final sheet = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _AdditionalReactionChoicesSheet(
        prompt: widget.prompt,
        choices: widget.choices.skip(2).toList(growable: false),
        projection: _projection,
        onDispatch: _dispatchReaction,
      ),
    );
    return sheet.whenComplete(() {
      _sheetOpen = false;
      if (mounted) {
        setState(() {});
      } else {
        _disposeProjection();
      }
    });
  }

  bool _dispatchReaction(String choiceId) {
    if (!mounted || !_projection.value.enabled) {
      return false;
    }
    widget.onReactionSelected(choiceId);
    return true;
  }

  @override
  void dispose() {
    _publishProjection(
      enabled: false,
      selectedReactionId: _projection.value.selectedReactionId,
    );
    if (!_sheetOpen) {
      _disposeProjection();
    }
    super.dispose();
  }

  void _publishProjection({
    required bool enabled,
    required String? selectedReactionId,
  }) {
    final current = _projection.value
      ..enabled = enabled
      ..selectedReactionId = selectedReactionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_projectionDisposed) {
        return;
      }
      if (current.enabled != enabled ||
          current.selectedReactionId != selectedReactionId) {
        return;
      }
      _projection.value = _ReactionControlProjection(
        enabled: enabled,
        selectedReactionId: selectedReactionId,
      );
    });
  }

  void _disposeProjection() {
    if (_projectionDisposed) {
      return;
    }
    _projectionDisposed = true;
    _projection.dispose();
  }
}

final class _ReactionControlProjection {
  _ReactionControlProjection({
    required this.enabled,
    required this.selectedReactionId,
  });

  bool enabled;
  String? selectedReactionId;
}

final class _AdditionalReactionChoicesSheet extends StatelessWidget {
  const _AdditionalReactionChoicesSheet({
    required this.prompt,
    required this.choices,
    required this.projection,
    required this.onDispatch,
  });

  final String prompt;
  final List<RitualReactionChoice> choices;
  final ValueListenable<_ReactionControlProjection> projection;
  final bool Function(String choiceId) onDispatch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('ritual-reaction-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                prompt,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder<_ReactionControlProjection>(
                  valueListenable: projection,
                  builder: (context, current, child) => ListView(
                    children: [
                      for (final choice in choices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Semantics(
                            label: choice.label,
                            button: true,
                            enabled: current.enabled,
                            selected: current.selectedReactionId == choice.id,
                            container: true,
                            excludeSemantics: true,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: current.enabled
                                  ? () {
                                      if (onDispatch(choice.id)) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  : null,
                              child: Text(choice.label),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
