import 'package:flutter/material.dart';

final class RitualReassurance extends StatelessWidget {
  const RitualReassurance({
    super.key,
    required this.message,
    required this.quietExitLabel,
    required this.onQuietExit,
  });

  final String message;
  final String quietExitLabel;
  final VoidCallback onQuietExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: quietExitLabel,
            button: true,
            container: true,
            excludeSemantics: true,
            child: TextButton(
              key: const Key('ritual-quiet-exit'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onQuietExit,
              child: Text(quietExitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
