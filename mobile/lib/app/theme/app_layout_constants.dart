import 'package:flutter/widgets.dart';

/// App-wide layout constants to eliminate magic numbers.
class AppLayoutConstants {
  AppLayoutConstants._();

  /// Tiny spacing used inside dense controls.
  static const double spacingXxs = 2;

  /// Compact spacing used between nearby labels and body copy.
  static const double spacingXs = 8;

  /// Small spacing used between inline icon and text clusters.
  static const double spacingSm = 12;

  /// Default component padding.
  static const double spacingMd = 16;

  /// Primary horizontal rhythm for screens and buttons.
  static const double spacingLg = 20;

  /// Large spacing used between grouped sections.
  static const double spacingXl = 24;

  /// Extra large spacing used for empty states.
  static const double spacing2xl = 32;

  /// Maximum content width for centered layouts (phones).
  static const double maxContentWidth = 430;

  /// Standard shell tab page padding (accommodates bottom navigation bar).
  static const EdgeInsets shellTabPadding = EdgeInsets.fromLTRB(
    spacingLg,
    spacingSm,
    spacingLg,
    120,
  );

  /// Standard standalone screen padding.
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(
    spacingLg,
    spacingLg,
    spacingLg,
    spacingXl,
  );

  /// Practice session screen padding.
  static const EdgeInsets practicePadding = EdgeInsets.fromLTRB(
    spacingLg,
    spacingSm,
    spacingLg,
    spacing2xl,
  );

  /// Standard horizontal content padding.
  static const double horizontalPadding = spacingLg;

  /// Standard border radius for cards.
  static const double cardRadius = 16;

  /// Small border radius for inputs, secondary buttons and tags (`--radius-sm`).
  static const double smallRadius = 8;

  /// Large border radius for hero cards and sheets.
  static const double largeRadius = 24;

  /// Medium border radius.
  static const double mediumRadius = 20;

  /// Fully rounded pill radius used by chips and badges.
  static const double pillRadius = 9999;

  /// Minimum interactive target size.
  static const double minTouchTarget = 48;

  /// Standard primary button height.
  static const double buttonMinHeight = 56;

  /// Standard input vertical padding.
  static const double inputVerticalPadding = 18;

  /// Shared input field padding.
  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(
    horizontal: spacingMd,
    vertical: inputVerticalPadding,
  );

  /// Shared primary button padding.
  static const EdgeInsets primaryButtonPadding = EdgeInsets.symmetric(
    horizontal: spacingLg,
    vertical: inputVerticalPadding,
  );

  /// Shared banner padding.
  static const EdgeInsets bannerPadding = EdgeInsets.all(spacingMd);

  /// Shared empty state padding.
  static const EdgeInsets emptyStatePadding = EdgeInsets.all(spacing2xl);

  /// Small icon size.
  static const double iconSizeSm = 16;

  /// Medium icon size.
  static const double iconSizeMd = 18;

  /// Large illustration icon size.
  static const double iconSizeLg = 40;

  /// Empty-state icon container size.
  static const double iconContainerLg = 80;

  /// Step progress segment height.
  static const double progressSegmentHeight = 4;

  /// Step progress segment radius.
  static const double progressSegmentRadius = 2;

  /// Step progress segment horizontal margin.
  static const double progressSegmentHorizontalMargin = spacingXxs;

  /// Step progress animation duration.
  static const Duration progressAnimationDuration = Duration(milliseconds: 300);
}
