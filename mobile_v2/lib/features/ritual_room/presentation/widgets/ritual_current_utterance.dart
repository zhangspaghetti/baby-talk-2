import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../domain/models/product_snapshot.dart';
import '../../domain/models/ritual_room_content.dart';
import '../models/ritual_listen_state.dart';
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
            snapshot.activeUtterance.primary,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.activeUtterance.zhSupport,
            style: textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 8),
          RitualActionCue(cue: actionCue, sortKey: const OrdinalSortKey(3)),
          RitualListenControl(
            state: audio.available
                ? const RitualListenReady()
                : const RitualListenUnavailable(),
            sortKey: const OrdinalSortKey(4),
            onPressed: onListen,
            readyLabel: audio.available ? audio.label : null,
          ),
          if (submitting) RitualSubmittingIndicator(message: pendingCopy),
        ],
      ),
    );
  }
}
