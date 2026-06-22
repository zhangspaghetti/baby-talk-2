import 'package:flutter/material.dart';

import '../../../../app/theme/ritual_room_theme.dart';
import '../../domain/models/ritual_atmosphere_tone.dart';
import '../../domain/models/ritual_room_content.dart';

final class RitualAtmosphereLayer extends StatelessWidget {
  const RitualAtmosphereLayer({
    super.key,
    required this.illustration,
    required this.tone,
    required this.roomName,
  });

  final RitualIllustration illustration;
  final RitualAtmosphereTone tone;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final ritualTheme =
        Theme.of(context).extension<RitualRoomTheme>() ?? RitualRoomTheme.light;
    final palette = ritualTheme.paletteFor(tone);
    final highContrast = MediaQuery.highContrastOf(context);

    return IgnorePointer(
      key: const Key('ritual-atmosphere-layer'),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final illustrationSize = (shortestSide * 0.28).clamp(88.0, 128.0);

            return DecoratedBox(
              key: const Key('ritual-atmosphere-field'),
              decoration: BoxDecoration(
                color: palette.canvas,
                gradient: highContrast
                    ? null
                    : RadialGradient(
                        center: const Alignment(0.05, -0.12),
                        radius: 0.78,
                        colors: [palette.lightField, palette.canvas],
                      ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 20,
                    left: 24,
                    right: illustrationSize + 48,
                    child: Text(
                      roomName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ritualTheme.textMuted.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 20,
                    width: illustrationSize,
                    height: illustrationSize,
                    child: Image.asset(
                      key: const Key('ritual-atmosphere-illustration'),
                      illustration.assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
