import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class ActivationFrame extends StatelessWidget {
  const ActivationFrame({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('activation-frame'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.english.withValues(alpha: 0.32),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142D2926),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('C3 激活框', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  stepLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
