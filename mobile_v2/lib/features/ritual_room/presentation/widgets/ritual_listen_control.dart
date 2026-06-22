import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/ritual_room_theme.dart';
import '../models/ritual_listen_state.dart';

final class RitualListenControl extends StatelessWidget {
  const RitualListenControl({
    super.key,
    required this.state,
    required this.sortKey,
    required this.onPressed,
    this.readyLabel,
  });

  final RitualListenState state;
  final SemanticsSortKey sortKey;
  final VoidCallback? onPressed;
  final String? readyLabel;

  @override
  Widget build(BuildContext context) {
    final copy = _copyOf(context);
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;
    final presentation = switch (state) {
      RitualListenUnavailable() => _ListenPresentation(
        label: copy.audioUnavailable,
        semanticsLabel: copy.audioUnavailable,
        icon: Icons.volume_off_outlined,
        enabled: false,
      ),
      RitualListenReady() || RitualListenPaused() => _ListenPresentation(
        label: readyLabel ?? copy.listen,
        semanticsLabel: readyLabel ?? copy.playSentenceSemantics,
        icon: Icons.play_arrow_rounded,
        enabled: onPressed != null,
      ),
      RitualListenLoading() => _ListenPresentation(
        label: copy.listen,
        semanticsLabel: copy.loadingAudioSemantics,
        enabled: false,
        loading: true,
      ),
      RitualListenPlaying() => _ListenPresentation(
        label: copy.pause,
        semanticsLabel: copy.pauseSentenceSemantics,
        icon: Icons.pause_rounded,
        enabled: onPressed != null,
      ),
      RitualListenFailure() => _ListenPresentation(
        label: copy.retry,
        semanticsLabel: copy.retry,
        icon: Icons.refresh_rounded,
        enabled: onPressed != null,
      ),
    };

    return Semantics(
      sortKey: sortKey,
      label: presentation.semanticsLabel,
      button: true,
      enabled: presentation.enabled,
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 48,
            child: presentation.loading
                ? const Padding(
                    key: Key('ritual-listen-control'),
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    key: const Key('ritual-listen-control'),
                    onPressed: presentation.enabled ? onPressed : null,
                    color: ritualTheme.assistive,
                    style: IconButton.styleFrom(
                      backgroundColor: ritualTheme.assistiveSurface,
                    ),
                    icon: Icon(presentation.icon),
                  ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              presentation.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: presentation.enabled
                    ? ritualTheme.assistive
                    : ritualTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ListenPresentation {
  const _ListenPresentation({
    required this.label,
    required this.semanticsLabel,
    required this.enabled,
    this.icon,
    this.loading = false,
  });

  final String label;
  final String semanticsLabel;
  final IconData? icon;
  final bool enabled;
  final bool loading;
}

AppLocalizations _copyOf(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('zh'));
