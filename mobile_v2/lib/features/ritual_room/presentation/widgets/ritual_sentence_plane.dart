import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/theme/ritual_room_theme.dart';
import '../../domain/models/active_utterance.dart';
import '../models/ritual_listen_state.dart';
import 'ritual_action_cue.dart';
import 'ritual_listen_control.dart';

final class RitualSentencePlane extends StatelessWidget {
  const RitualSentencePlane({
    super.key,
    required this.utterance,
    required this.listenState,
    required this.onListen,
    required this.motionDuration,
  });

  final ActiveUtterance utterance;
  final RitualListenState listenState;
  final VoidCallback? onListen;
  final Duration motionDuration;

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;

    return Padding(
      key: const Key('ritual-sentence-plane'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: motionDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final fade = FadeTransition(opacity: animation, child: child);
              if (motionDuration <= const Duration(milliseconds: 80)) {
                return fade;
              }
              return SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                child: fade,
              );
            },
            child: Column(
              key: ValueKey(utterance.displayId),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  key: const Key('ritual-primary-sentence'),
                  sortKey: const OrdinalSortKey(1),
                  label: utterance.primary,
                  container: true,
                  excludeSemantics: true,
                  child: Text(
                    utterance.primary,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: ritualTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  key: const Key('ritual-zh-support'),
                  sortKey: const OrdinalSortKey(2),
                  label: utterance.zhSupport,
                  container: true,
                  excludeSemantics: true,
                  child: Text(
                    utterance.zhSupport,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ritualTheme.textSecondary,
                    ),
                  ),
                ),
                RitualActionCue(
                  cue: utterance.actionCue,
                  sortKey: const OrdinalSortKey(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RitualListenControl(
            state: listenState,
            sortKey: const OrdinalSortKey(4),
            onPressed: onListen,
          ),
        ],
      ),
    );
  }
}
