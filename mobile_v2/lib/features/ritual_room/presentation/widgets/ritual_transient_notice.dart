import 'package:flutter/material.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/ritual_room_theme.dart';

final class RitualTransientNotice extends StatelessWidget {
  const RitualTransientNotice({
    super.key,
    required this.message,
    this.liveRegion = true,
    this.onRetry,
  });

  final String message;
  final bool liveRegion;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;
    final copy = AppLocalizations.of(context);

    return Semantics(
      key: const Key('ritual-transient-notice'),
      liveRegion: liveRegion,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ritualTheme.assistiveSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ritualTheme.textPrimary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('ritual-transient-notice-retry'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: Text(copy.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
