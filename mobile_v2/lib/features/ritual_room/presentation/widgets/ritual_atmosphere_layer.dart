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
                // Soft central luminosity lift over the reading zone (design
                // §3.4); no edge darkening so the figure blends into the canvas.
                gradient: highContrast
                    ? null
                    : RadialGradient(
                        center: const Alignment(0.0, -0.28),
                        radius: 1.25,
                        colors: [palette.lightField, palette.canvas],
                        stops: const [0.0, 0.85],
                      ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The visible "sentence light field": a soft pool of light in
                  // the upper reading zone that holds the sentence, fading to the
                  // canvas before it reaches the corner figure. No card edge.
                  if (!highContrast)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.05, -0.46),
                            radius: 0.92,
                            colors: [
                              Color(0xFFFFFEFC),
                              Color(0xFAFFFEFC),
                              Color(0x00FFFEFC),
                              Color(0x14302A26),
                              Color(0x00302A26),
                            ],
                            stops: [0.0, 0.2, 0.42, 0.64, 0.9],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 22,
                    left: 24,
                    right: illustrationSize + 48,
                    child: Text(
                      roomName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ritualTheme.textMuted.withValues(alpha: 0.64),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 12,
                    width: illustrationSize,
                    height: illustrationSize,
                    child: _FeatheredIllustration(
                      assetPath: illustration.assetPath,
                      highContrast: highContrast,
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

/// Dissolves the edge illustration into the canvas so it reads as an emotional
/// container entering from the corner, never a pasted-on sticker (design §3.2).
final class _FeatheredIllustration extends StatelessWidget {
  const _FeatheredIllustration({
    required this.assetPath,
    required this.highContrast,
  });

  final String assetPath;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      key: const Key('ritual-atmosphere-illustration'),
      assetPath,
      fit: BoxFit.contain,
    );

    if (highContrast) {
      return image;
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const RadialGradient(
        center: Alignment(0.0, 0.05),
        radius: 0.78,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(bounds),
      child: Opacity(opacity: 0.9, child: image),
    );
  }
}
