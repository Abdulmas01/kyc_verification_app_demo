import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/theme/app_colors.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';

enum InfoBannerTone { warning, info, success, error }

class InfoBannerCardWidget extends StatelessWidget {
  const InfoBannerCardWidget({
    super.key,
    this.tone = InfoBannerTone.warning,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 12,
    required this.child,
  });

  final InfoBannerTone tone;
  final EdgeInsets padding;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(context, tone);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      padding: padding,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.border),
      ),
      child: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodySmall,
        child: IconTheme.merge(
          data: IconThemeData(color: colors.icon),
          child: child,
        ),
      ),
    );
  }
}

class _BannerColors {
  final Color bg;
  final Color border;
  final Color icon;

  const _BannerColors({
    required this.bg,
    required this.border,
    required this.icon,
  });
}

_BannerColors _toneColors(BuildContext context, InfoBannerTone tone) {
  switch (tone) {
    case InfoBannerTone.warning:
      return _BannerColors(
        bg: AppColors.statusWarning.withOpacity(0.10),
        border: AppColors.statusWarning.withOpacity(0.20),
        icon: AppColors.statusWarning,
      );
    case InfoBannerTone.info:
      return _BannerColors(
        bg: AppColors.statusInfo.withOpacity(0.10),
        border: AppColors.statusInfo.withOpacity(0.20),
        icon: AppColors.statusInfo,
      );
    case InfoBannerTone.success:
      return _BannerColors(
        bg: AppColors.statusSuccess.withOpacity(0.10),
        border: AppColors.statusSuccess.withOpacity(0.20),
        icon: AppColors.statusSuccess,
      );
    case InfoBannerTone.error:
      return _BannerColors(
        bg: AppColors.statusError.withOpacity(0.10),
        border: AppColors.statusError.withOpacity(0.20),
        icon: AppColors.statusError,
      );
  }
}
