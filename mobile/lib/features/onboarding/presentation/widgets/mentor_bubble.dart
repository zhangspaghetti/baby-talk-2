import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class MentorBubble extends StatelessWidget {
  const MentorBubble({
    super.key,
    required this.message,
    this.caption,
    this.trailing,
  });

  final String message;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.bgAccentSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '禾',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              border: Border.all(color: AppTheme.outlineSoft),
              boxShadow: AppTheme.warmShadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null) ...[
                  Text(
                    caption!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.accentDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
