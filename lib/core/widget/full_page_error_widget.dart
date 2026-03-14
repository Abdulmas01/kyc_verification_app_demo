import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/exception/network_exception.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/network/constants.dart';
import 'package:kyc_verification_app_demo/core/theme/app_colors.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class FullPageErrorWidget extends StatelessWidget {
  const FullPageErrorWidget({
    super.key,
    this.error,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final Object? error;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData? icon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final presentation = _resolvePresentation(error, title, message, icon);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      presentation.icon,
                      size: 54,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                Text(
                  presentation.title,
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  presentation.message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.getSecondaryTextColor(context),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  SizedBox(
                    width: double.infinity,
                    child: ButtonWidget(
                      onTap: onRetry,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      child: Text(
                        retryLabel,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                if (secondaryActionLabel != null &&
                    onSecondaryAction != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  SizedBox(
                    width: double.infinity,
                    child: ButtonWidget(
                      onTap: onSecondaryAction,
                      type: ButtonType.secondary,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      child: Text(
                        secondaryActionLabel!,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

_ErrorPresentation _resolvePresentation(
  Object? error,
  String? title,
  String? message,
  IconData? icon,
) {
  if (icon != null && title != null && message != null) {
    return _ErrorPresentation(title: title, message: message, icon: icon);
  }

  if (error is NetworkException) {
    final code = int.tryParse(error.statusCode ?? "");
    if (code != null && code >= 500) {
      return _ErrorPresentation(
        title: title ?? 'Server Error',
        message: message ??
            'We\'re having trouble on our servers. Please try again shortly.',
        icon: icon ?? Symbols.dns,
      );
    }

    if (error.message == kUnableToConnect) {
      return _ErrorPresentation(
        title: title ?? 'Connection Lost',
        message: message ?? error.message,
        icon: icon ?? Symbols.wifi_off,
      );
    }

    return _ErrorPresentation(
      title: title ?? 'Something went wrong',
      message: message ?? error.message,
      icon: icon ?? Symbols.error,
    );
  }

  return _ErrorPresentation(
    title: title ?? 'An error occurred',
    message: message ?? error?.toString() ?? kSomethingWentWrong,
    icon: icon ?? Symbols.error,
  );
}

class _ErrorPresentation {
  const _ErrorPresentation({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}
