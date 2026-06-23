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
        child: Text(
          cue,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: ritualTheme.warmAccent,
          ),
        ),
      ),
    );
  }
}

AppLocalizations _copyOf(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('zh'));
