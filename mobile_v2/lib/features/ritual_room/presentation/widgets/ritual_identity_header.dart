import 'package:flutter/material.dart';

import '../../domain/models/ritual_room_content.dart';

final class RitualIdentityHeader extends StatelessWidget {
  const RitualIdentityHeader({
    super.key,
    required this.illustration,
    required this.roomName,
    required this.routineAnchor,
    required this.anchorPhrase,
    required this.chineseHelper,
  });

  final RitualIllustration illustration;
  final String roomName;
  final String routineAnchor;
  final String anchorPhrase;
  final String chineseHelper;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('ritual-identity-header'),
      height: 196,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 112,
            child: ExcludeSemantics(
              child: Image.asset(illustration.assetPath, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  routineAnchor,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  anchorPhrase,
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chineseHelper,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
