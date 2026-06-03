import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// A seedling-themed progress bar showing weekly learning progress.
///
/// Displays a warm orange fill with a small sprout icon at the progress point,
/// set against a cream sunken background.
class HomeProgressBar extends StatelessWidget {
  const HomeProgressBar({
    super.key,
    required this.progress,
    this.label,
  });

  /// Progress value from 0.0 to 1.0.
  final double progress;

  /// Optional label displayed above the progress bar.
  final String? label;

  static const double _trackHeight = 8;
  static const double _containerHeight = 48;
  static const double _thumbSize = 24;
  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      key: const Key('home-progress-bar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            key: const Key('home-progress-bar-label'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
        ],
        SizedBox(
          height: _containerHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final thumbOffset =
                  (trackWidth * clampedProgress).clamp(0.0, trackWidth);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track background
                  Positioned(
                    top: (_containerHeight - _trackHeight) / 2,
                    left: 0,
                    right: 0,
                    height: _trackHeight,
                    child: Container(
                      key: const Key('home-progress-bar-track'),
                      decoration: BoxDecoration(
                        color: colors.bgSunken,
                        borderRadius:
                            BorderRadius.circular(AppLayoutConstants.smallRadius),
                      ),
                    ),
                  ),
                  // Fill
                  Positioned(
                    top: (_containerHeight - _trackHeight) / 2,
                    left: 0,
                    width: trackWidth * clampedProgress,
                    height: _trackHeight,
                    child: Container(
                      key: const Key('home-progress-bar-fill'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.accent, colors.accentDark],
                          stops: const [0.0, 1.0],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppLayoutConstants.smallRadius),
                      ),
                    ),
                  ),
                  // Seedling thumb
                  Positioned(
                    top: (_containerHeight - _thumbSize) / 2,
                    left: thumbOffset - _thumbSize / 2,
                    child: Container(
                      key: const Key('home-progress-bar-thumb'),
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        shape: BoxShape.circle,
                        boxShadow: colors.warmShadowSm,
                      ),
                      child: Icon(
                        Icons.eco,
                        key: const Key('home-progress-bar-icon'),
                        size: _iconSize,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
