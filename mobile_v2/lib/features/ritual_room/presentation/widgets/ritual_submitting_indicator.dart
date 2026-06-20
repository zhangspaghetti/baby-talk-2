import 'package:flutter/material.dart';

final class RitualSubmittingIndicator extends StatelessWidget {
  const RitualSubmittingIndicator({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
