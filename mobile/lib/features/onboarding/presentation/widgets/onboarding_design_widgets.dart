import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';

class OnboardingAssets {
  const OnboardingAssets._();

  static const mentor = 'assets/images/emotions/emotions_03.png';
  static const mentorPraying = 'assets/images/emotions/emotions_05.png';
  static const mentorPointing = 'assets/images/emotions/emotions_07.png';
  static const bedtime = 'assets/images/plants/plants_13.png';
  static const feeding = 'assets/images/activities/activities_10.png';
  static const bath = 'assets/images/baby_items/baby_items_10.png';
  static const diaper = 'assets/images/baby_items/baby_items_08.png';
  static const sprout = 'assets/images/plants/plants_20.png';
  static const seed = 'assets/images/plants/plants_26.png';
  static const flower = 'assets/images/plants/plants_15.png';
  static const flowerSprout = 'assets/images/plants/plants_17.png';
  static const wildflowers = 'assets/images/plants/plants_16.png';
  static const pottedFlower = 'assets/images/mentor/mentor_07.png';
  static const gardenFence = 'assets/images/mentor/mentor_09.png';
  static const woodSign = 'assets/images/mentor/mentor_03.png';
  static const happy = 'assets/images/activities/activities_16.png';
  static const neutral = 'assets/images/activities/activities_19.png';
  static const heart = 'assets/images/plants/plants_27.png';
}

class OnboardingWarmScaffold extends StatelessWidget {
  const OnboardingWarmScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF5), Color(0xFFFFF6EA)],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutConstants.maxContentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingAssetImage extends StatelessWidget {
  const OnboardingAssetImage(
    this.assetName, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );
  }
}

class OnboardingMentorBubble extends StatelessWidget {
  const OnboardingMentorBubble({
    super.key,
    required this.message,
    this.assetName = OnboardingAssets.mentor,
    this.maxWidth,
    this.showAvatar = true,
  });

  final String message;
  final String assetName;
  final double? maxWidth;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showAvatar) ...[
          ClipOval(
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.bgAccentSoft),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: OnboardingAssetImage(assetName, width: 58, height: 58),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 260),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEEDDC8)),
              ),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return AppScaleButton(
      scaleDown: onPressed == null ? 1 : 0.97,
      onTap: onPressed == null
          ? null
          : () {
              AppHaptics.lightTap();
              onPressed!();
            },
      child: Opacity(
        opacity: onPressed == null ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9A2E), Color(0xFFFF7F13)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF8C42),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingOutlinedButton extends StatelessWidget {
  const OnboardingOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppScaleButton(
      scaleDown: onPressed == null ? 1 : 0.97,
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9CBA8)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final fraction = (current / safeTotal).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: const Color(0xFFEFE4D6)),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB86B2A), Color(0xFFFF8C42)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$current / $safeTotal',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
