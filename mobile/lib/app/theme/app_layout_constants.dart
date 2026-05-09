import 'package:flutter/widgets.dart';

/// App-wide layout constants to eliminate magic numbers.
class AppLayoutConstants {
  AppLayoutConstants._();

  /// Maximum content width for centered layouts (phones).
  static const double maxContentWidth = 430;

  /// Standard shell tab page padding (accommodates bottom navigation bar).
  static const EdgeInsets shellTabPadding = EdgeInsets.fromLTRB(20, 12, 20, 120);

  /// Standard standalone screen padding.
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(20, 20, 20, 24);

  /// Practice session screen padding.
  static const EdgeInsets practicePadding = EdgeInsets.fromLTRB(20, 12, 20, 32);

  /// Standard horizontal content padding.
  static const double horizontalPadding = 20;

  /// Standard border radius for cards.
  static const double cardRadius = 16;

  /// Large border radius for hero cards and sheets.
  static const double largeRadius = 24;

  /// Medium border radius.
  static const double mediumRadius = 20;
}
