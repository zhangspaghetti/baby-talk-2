import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class MiniSeedCard extends StatelessWidget {
  const MiniSeedCard({super.key, required this.english, required this.chinese});

  final String english;
  final String chinese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('onboarding-mini-seed-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.englishSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.info),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.bgSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.play_arrow_rounded, color: AppTheme.info),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第一颗种子',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  english,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 24,
                    height: 1.3,
                    color: AppTheme.english,
                  ),
                ),
                if (chinese.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    chinese,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
