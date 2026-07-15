import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';

/// Decorative botanical header for the BabyTalk 2 home screen.
///
/// Displays a warm brown gradient with centered title, settings gear,
/// and flat-art botanical illustrations (tulips, daisies, leaves).
class HomeBotanicalHeader extends StatelessWidget {
  const HomeBotanicalHeader({super.key});

  // Header dimensions
  static const double _headerHeight = 220;
  static const double _settingsButtonSize = 46;
  static const double _settingsIconSize = 26;
  static const double _titleFontSize = 24;
  static const double _titleLetterSpacing = 0.5;

  // Colors
  static const Color _gradientTop = Color(0xFF6B4F3A);
  static const Color _gradientBottom = Color(0xFF5C4033);
  static const Color _textColor = Color(0xFFF5F0EB);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Baby Talk 2 home header',
      child: SizedBox(
        key: const Key('botanical-header'),
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: _headerHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_gradientTop, _gradientBottom],
              ),
            ),
            child: Stack(
              children: [
                // Botanical illustrations layer
                _buildBotanicalIllustrations(),

                // Settings gear — top right
                Positioned(
                  top: AppLayoutConstants.spacingSm,
                  right: AppLayoutConstants.spacingMd,
                  child: Semantics(
                    label: 'Settings',
                    button: true,
                    child: GestureDetector(
                      key: const Key('botanical-settings-gear'),
                      onTap: () => context.push(AppRouteNames.meSettings),
                      child: SizedBox(
                        width: _settingsButtonSize,
                        height: _settingsButtonSize,
                        child: const Icon(
                          Icons.settings_outlined,
                          color: _textColor,
                          size: _settingsIconSize,
                        ),
                      ),
                    ),
                  ),
                ),

                // Centered title
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'Baby Talk 2',
                      key: Key('botanical-title'),
                      style: TextStyle(
                        color: _textColor,
                        fontSize: _titleFontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: _titleLetterSpacing,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotanicalIllustrations() {
    return Stack(
      children: const [
        // Left tulip cluster
        _BotanicalEmoji(
          emoji: '🌷',
          top: 12,
          left: 16,
          size: 28,
          opacity: 0.7,
          key: Key('botanical-tulip-left'),
        ),
        _BotanicalEmoji(
          emoji: '🌿',
          top: 8,
          left: 52,
          size: 22,
          opacity: 0.5,
          key: Key('botanical-leaf-left'),
        ),

        // Center daisy cluster
        _BotanicalEmoji(
          emoji: '🌼',
          top: 40,
          left: 80,
          size: 26,
          opacity: 0.65,
          key: Key('botanical-daisy-center'),
        ),
        _BotanicalEmoji(
          emoji: '🌱',
          top: 35,
          left: 120,
          size: 20,
          opacity: 0.55,
          key: Key('botanical-sprout-center'),
        ),

        // Right tulip cluster
        _BotanicalEmoji(
          emoji: '🌷',
          top: 15,
          right: 20,
          size: 28,
          opacity: 0.7,
          key: Key('botanical-tulip-right'),
        ),
        _BotanicalEmoji(
          emoji: '🌼',
          top: 30,
          right: 60,
          size: 24,
          opacity: 0.6,
          key: Key('botanical-daisy-right'),
        ),
        _BotanicalEmoji(
          emoji: '🌿',
          top: 10,
          right: 100,
          size: 22,
          opacity: 0.5,
          key: Key('botanical-leaf-right'),
        ),

        // Bottom accent leaves
        _BotanicalEmoji(
          emoji: '🌱',
          bottom: 20,
          left: 40,
          size: 20,
          opacity: 0.5,
          key: Key('botanical-sprout-bottom-left'),
        ),
        _BotanicalEmoji(
          emoji: '🌿',
          bottom: 25,
          right: 50,
          size: 22,
          opacity: 0.55,
          key: Key('botanical-leaf-bottom-right'),
        ),
      ],
    );
  }
}

/// Private widget for displaying a botanical emoji with opacity.
class _BotanicalEmoji extends StatelessWidget {
  const _BotanicalEmoji({
    required this.emoji,
    required super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.size = 24,
    this.opacity = 0.6,
  });

  final String emoji;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: key,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Opacity(
        opacity: opacity,
        child: Text(
          emoji,
          style: TextStyle(fontSize: size),
        ),
      ),
    );
  }
}
