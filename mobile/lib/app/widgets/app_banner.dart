import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';

/// Unified banner widget replacing 8+ private banner variants across the app.
///
/// Supports optional [icon], optional action button ([actionLabel] + [onAction]),
/// and optional [onDismiss] for dismissible banners.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.onDismiss,
    this.borderRadius = AppLayoutConstants.cardRadius,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppLayoutConstants.bannerPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppLayoutConstants.spacingXxs,
                  ),
                  child: Icon(
                    icon,
                    color: foregroundColor,
                    size: AppLayoutConstants.iconSizeMd,
                  ),
                ),
                const SizedBox(width: AppLayoutConstants.spacingSm),
              ],
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onDismiss != null)
                Semantics(
                  button: true,
                  label: 'Dismiss',
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppLayoutConstants.spacingXs,
                      ),
                      child: Icon(
                        Icons.close,
                        color: foregroundColor.withValues(alpha: 0.6),
                        size: AppLayoutConstants.iconSizeSm,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppLayoutConstants.spacingSm),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
