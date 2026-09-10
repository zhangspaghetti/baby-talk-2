import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class HomeV23ActivitySlots extends StatelessWidget {
  const HomeV23ActivitySlots({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 32),
        _ActivitySlot(
          title: 'TPR 小动作',
          subtitle: '顺手做一个，强化肌肉记忆',
          icon: Icons.accessibility_new_rounded,
        ),
        SizedBox(height: 12),
        _ActivitySlot(
          title: '绘本补一句',
          subtitle: '翻开书，指着念一句',
          icon: Icons.menu_book_rounded,
        ),
        SizedBox(height: 12),
        _ActivitySlot(
          title: '小禾提醒',
          subtitle: '今天别忘了及时表扬',
          icon: Icons.lightbulb_outline_rounded,
        ),
      ],
    );
  }
}

class _ActivitySlot extends StatelessWidget {
  const _ActivitySlot({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  void _showActivitySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('了解'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: InkWell(
        onTap: () => _showActivitySheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bgAccentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.accentDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colors.outlineSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
