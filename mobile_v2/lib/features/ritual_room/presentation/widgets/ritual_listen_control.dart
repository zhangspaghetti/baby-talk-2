import 'package:flutter/material.dart';

final class RitualListenControl extends StatelessWidget {
  const RitualListenControl({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 48,
            child: IconButton.filled(
              key: const Key('ritual-listen-control'),
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
