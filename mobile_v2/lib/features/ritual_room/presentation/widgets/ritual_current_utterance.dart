import 'package:flutter/material.dart';

import '../../domain/models/product_snapshot.dart';
import '../../domain/models/ritual_room_content.dart';
import 'ritual_action_cue.dart';
import 'ritual_listen_control.dart';
import 'ritual_submitting_indicator.dart';

final class RitualCurrentUtterance extends StatelessWidget {
  const RitualCurrentUtterance({
    super.key,
    required this.snapshot,
    required this.actionCue,
    required this.audio,
    required this.submitting,
    required this.pendingCopy,
    required this.onListen,
  });

  final ProductSnapshot snapshot;
  final String actionCue;
  final RitualAudioContent audio;
  final bool submitting;
  final String pendingCopy;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.revision == 0)
            Text(
              snapshot.normalizedContext.eventSummary,
              style: textTheme.labelLarge?.copyWith(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            RichText(
              text: TextSpan(
                text: snapshot.normalizedContext.eventSummary,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            snapshot.utterance.primary,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.utterance.zhHelper,
            style: textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 8),
          RitualListenControl(
            label: audio.label,
            onPressed: onListen,
            enabled: audio.available,
          ),
          RitualActionCue(cue: actionCue),
          if (submitting) RitualSubmittingIndicator(message: pendingCopy),
        ],
      ),
    );
  }
}
