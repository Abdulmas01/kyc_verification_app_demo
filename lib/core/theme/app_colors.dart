import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F9D58);
  static const Color primaryGreen = Color(0xFF0F9D58);
  static const Color primaryGreenDark = Color(0xFF0B7A45);
  static const Color primaryEmerald = Color(0xFF4ADE80);
  static const Color accentGreen = Color(0xFF22C55E);

  static const Color secondaryBlack600 = Color(0xFF111827);

  static const Color statusSuccess = Color(0xFF16A34A);
  static const Color statusSuccessLight = Color(0xFF86EFAC);
  static const Color statusSuccessDark = Color(0xFF15803D);

  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusWarningLight = Color(0xFFFCD34D);
  static const Color statusWarningDark = Color(0xFFD97706);

  static const Color statusError = Color(0xFFDC2626);
  static const Color statusErrorLight = Color(0xFFFCA5A5);
  static const Color statusErrorDark = Color(0xFFB91C1C);

  static const Color statusInfo = Color(0xFF2563EB);
  static const Color statusInfoLight = Color(0xFF93C5FD);
  static const Color statusInfoDark = Color(0xFF1D4ED8);

  static const Color success = statusSuccess;
  static const Color warning = statusWarning;
  static const Color error = statusError;
  static const Color info = statusInfo;

  static const Color bgPrimary = Color(0xFFF9FAFB);
  static const Color bgSecondary = Color(0xFFFFFFFF);
  static const Color bgTertiary = Color(0xFFF3F4F6);

  static const Color darkBgPrimary = Color(0xFF0B1220);
  static const Color darkBgSecondary = Color(0xFF0F172A);
  static const Color darkBgTertiary = Color(0xFF111B2E);
  static const Color darkBgQuaternary = Color(0xFF17233A);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0F172A);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);

  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDefault = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF9CA3AF);

  static const Color darkBorderLight = Color(0xFF1F2A44);
  static const Color darkBorderDefault = Color(0xFF2A385A);
  static const Color darkBorderDark = Color(0xFF3A4B74);

  static const Color shadowLight = Color.fromRGBO(17, 24, 39, 0.04);
  static const Color shadowDefault = Color.fromRGBO(17, 24, 39, 0.08);
  static const Color shadowMedium = Color.fromRGBO(17, 24, 39, 0.12);
  static const Color shadowDark = Color.fromRGBO(17, 24, 39, 0.16);

  static const Color darkShadowLight = Color.fromRGBO(0, 0, 0, 0.18);
  static const Color darkShadowDefault = Color.fromRGBO(0, 0, 0, 0.28);
  static const Color darkShadowMedium = Color.fromRGBO(0, 0, 0, 0.38);
  static const Color darkShadowDark = Color.fromRGBO(0, 0, 0, 0.48);

  static const Color overlayLight = Color.fromRGBO(0, 0, 0, 0.55);
  static const Color overlayDark = Color.fromRGBO(0, 0, 0, 0.70);

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? bgPrimary
        : darkBgPrimary;
  }

  static Color getSecondaryBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? bgSecondary
        : darkBgSecondary;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textPrimary
        : darkTextPrimary;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textSecondary
        : darkTextSecondary;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? borderLight
        : darkBorderLight;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? surfaceLight
        : surfaceDark;
  }

  static Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? shadowDefault
        : darkShadowDefault;
  }
}
