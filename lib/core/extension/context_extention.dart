import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';

extension BuilContextExt on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;

  /// Default padding for all page in the app
  /// ```dart
  /// EdgeInsets.all(20)
  /// ```
  EdgeInsets get pagePadding => const EdgeInsets.all(20);

  /// Default page padding without bottom inset (bottom = 0).
  EdgeInsets get pagePaddingNoBottom =>
      const EdgeInsets.fromLTRB(20, 20, 20, 0);

  /// Default page padding without top or bottom inset (top = 0, bottom = 0).
  EdgeInsets get pagePaddingNoTopBottom =>
      const EdgeInsets.fromLTRB(20, 0, 20, 0);
  EdgeInsets get appBarTitlePadding => const EdgeInsets.only(right: 13);

  /// The parts of the display that are partially obscured by system UI,
  /// typically by the hardware display "notches" or the system status bar.
  EdgeInsets get systemUiPadding => MediaQuery.of(this).padding;

  /// default content padding for text fields and the custom dropdown created
  EdgeInsetsGeometry get defaultContentPadding =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 18);

  /// default suffix icon constraints for text fields and the custom dropdown created
  BoxConstraints get defaultSuffixIconConstraints =>
      const BoxConstraints(minHeight: 16, minWidth: 16);

  double get sectionSpacing => AppSpacing.s12;
  double get sectionTextSpacing => AppSpacing.s4;
}
