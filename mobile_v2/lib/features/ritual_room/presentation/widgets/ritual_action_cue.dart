import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/ritual_room_theme.dart';

final class RitualActionCue extends StatelessWidget {
  const RitualActionCue({super.key, required this.cue, required this.sortKey});

  final String cue;
  final SemanticsSortKey sortKey;

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;

    return Semantics(
      key: const Key('ritual-action-cue'),
      sortKey: sortKey,
      label: _copyOf(context).timingSemantics(cue),
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 8, top: 6),
              decoration: BoxDecoration(
                color: ritualTheme.warmAccent,
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(
                cue,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ritualTheme.warmAccent,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

AppLocalizations _copyOf(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('zh'));
