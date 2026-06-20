import 'package:flutter/material.dart';

final class RitualActionCue extends StatelessWidget {
  const RitualActionCue({super.key, required this.cue});

  final String cue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        cue,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
