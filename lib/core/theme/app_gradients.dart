import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradient {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primaryGreen, AppColors.accentGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryDark = LinearGradient(
    colors: [AppColors.primaryEmerald, AppColors.primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.accentGreen],
  );

  static LinearGradient adaptive(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? primary
        : primaryDark;
  }
}
