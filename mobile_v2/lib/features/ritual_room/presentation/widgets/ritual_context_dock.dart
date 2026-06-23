import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/ritual_room_theme.dart';
import '../../domain/models/ritual_room_content.dart';
import 'ritual_context_choices.dart';
import 'ritual_transient_notice.dart';

enum RitualDockRequestStatus {
  idle,
  submitting,
  recoverableFailure,
  unknownOutcome,
  reconciling,
}

final class RitualContextDock extends StatelessWidget {
  const RitualContextDock({
    super.key,
    required this.expanded,
    required this.requestStatus,
    required this.prompt,
    required this.reassurance,
    required this.quietExitLabel,
    required this.choices,
    required this.selectedReactionId,
    required this.notice,
    required this.onToggleExpanded,
    required this.onReactionSelected,
    required this.onReconcileUnknown,
    required this.onQuietExit,
  });

  final bool expanded;
  final RitualDockRequestStatus requestStatus;
  final String prompt;
  final String reassurance;
  final String quietExitLabel;
  final List<RitualReactionChoice> choices;
  final String? selectedReactionId;
  final String? notice;
  final ValueChanged<bool> onToggleExpanded;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback? onReconcileUnknown;
  final VoidCallback onQuietExit;

  bool get _choicesEnabled => switch (requestStatus) {
    RitualDockRequestStatus.idle ||
    RitualDockRequestStatus.recoverableFailure => true,
    RitualDockRequestStatus.submitting ||
    RitualDockRequestStatus.unknownOutcome ||
    RitualDockRequestStatus.reconciling => false,
  };

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;
    final copy = AppLocalizations.of(context);

    return DecoratedBox(
      key: Key(
        expanded
            ? 'ritual-context-dock-expanded'
            : 'ritual-context-dock-collapsed',
      ),
      decoration: BoxDecoration(
        color: ritualTheme.lightField,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ritualTheme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: expanded
            ? _buildExpanded(context, copy)
            : _buildCollapsed(context, copy),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, AppLocalizations copy) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;

    return Semantics(
      key: const Key('ritual-context-entry'),
      sortKey: const OrdinalSortKey(5),
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: ritualTheme.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => onToggleExpanded(true),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    copy.contextEntry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, AppLocalizations copy) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final estimatedChoiceRows = (choices.length / 2).ceil();
        final estimatedContentHeight =
            (248 + (estimatedChoiceRows * 56)) * textScale;
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              key: const Key('ritual-context-entry'),
              sortKey: const OrdinalSortKey(5),
              container: true,
              child: TextButton(
                key: const Key('ritual-context-collapse'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  foregroundColor: ritualTheme.assistive,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => onToggleExpanded(false),
                child: Text(copy.collapseContext),
              ),
            ),
            Text(
              prompt,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ritualTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reassurance,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: ritualTheme.textSecondary),
            ),
            if (notice != null) ...[
              const SizedBox(height: 12),
              RitualTransientNotice(
                message: notice!,
                onRetry: requestStatus == RitualDockRequestStatus.unknownOutcome
                    ? onReconcileUnknown
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            RitualContextChoices(
              choices: choices,
              enabled: _choicesEnabled,
              selectedReactionId: selectedReactionId,
              onSelected: onReactionSelected,
            ),
            const SizedBox(height: 8),
            Semantics(
              key: const Key('ritual-quiet-exit'),
              sortKey: const OrdinalSortKey(6),
              container: true,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: ritualTheme.textMuted,
                ),
                onPressed: onQuietExit,
                child: Text(quietExitLabel),
              ),
            ),
          ],
        );

        final requiresScroll =
            constraints.hasBoundedHeight &&
            constraints.maxHeight < estimatedContentHeight;
        if (!requiresScroll) {
          return content;
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: content,
          ),
        );
      },
    );
  }
}
