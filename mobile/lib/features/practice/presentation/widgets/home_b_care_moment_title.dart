import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Care moment title widget for Home B (Scene-mentor direction).
///
/// Displays a warm, contextual title that frames the current care moment,
/// e.g., "今晚 3 分钟，陪宝宝收个尾".
class HomeBCareMomentTitle extends StatelessWidget {
  const HomeBCareMomentTitle({
    super.key,
    required this.sceneTag,
    required this.sceneTitle,
    this.childName,
  });

  final String sceneTag;
  final String sceneTitle;
  final String? childName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final hour = DateTime.now().hour;
    final timeWord = hour < 12
        ? '早上'
        : hour < 18
            ? '下午'
            : '今晚';

    return Column(
      key: const Key('home-b-care-moment-title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time + care moment headline
        RichText(
          text: TextSpan(
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            children: [
              TextSpan(text: '$timeWord，'),
              TextSpan(
                text: '陪${childName ?? '宝宝'}$sceneTitle',
                style: TextStyle(color: colors.accentDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Scene tag pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            sceneTag,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.accentDark,
            ),
          ),
        ),
      ],
    );
  }
}
