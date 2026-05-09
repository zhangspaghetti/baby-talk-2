import 'package:flutter/services.dart';

/// Haptic feedback utility for tactile confirmations.
class AppHaptics {
  AppHaptics._();

  static void lightTap() => HapticFeedback.lightImpact();
  static void mediumTap() => HapticFeedback.mediumImpact();
  static void heavyTap() => HapticFeedback.heavyImpact();
  static void selectionClick() => HapticFeedback.selectionClick();
}
