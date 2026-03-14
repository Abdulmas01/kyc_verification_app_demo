import 'package:flutter/material.dart';

extension AppTextThemeExt on TextTheme {
  TextStyle sectionTitle(BuildContext context) => titleLarge!.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: Theme.of(context).colorScheme.onSurface,
      );

  TextStyle labelMuted(BuildContext context) => bodySmall!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(context).hintColor,
      );

  TextStyle pill(BuildContext context) => bodySmall!.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: Theme.of(context).colorScheme.onSurface,
      );

  TextStyle moneyOnGradient() => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: Colors.white,
      );
}
