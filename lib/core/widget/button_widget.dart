import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_colors.dart';

enum ButtonType { primary, secondary, danger }

class ButtonWidget extends StatelessWidget {
  final String? text;
  final TextStyle? textStyle;
  final Widget? child;
  final VoidCallback? onTap;

  final ButtonType type;

  final bool enabled;
  final AsyncValue? asyncState;
  final bool showLoadingState;

  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  final Color? backgroundColor;
  final Color? foregroundColor;

  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  final Color? borderColor;
  final double? borderWidth;

  final Color? loadingColor;

  const ButtonWidget({
    super.key,
    this.text,
    this.textStyle,
    this.child,
    this.onTap,
    this.type = ButtonType.primary,
    this.enabled = true,
    this.asyncState,
    this.showLoadingState = true,
    this.minimumSize = const Size(64, 40),
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderColor,
    this.borderWidth,
    this.loadingColor,
  });

  bool get _isLoading => asyncState is AsyncLoading && showLoadingState;
  bool get _isDisabled => !enabled || asyncState is AsyncLoading;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = _isDisabled
        ? null
        : () {
            FocusManager.instance.primaryFocus?.unfocus();
            onTap?.call();
          };

    final Widget content = _isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: loadingColor ?? _resolvedForeground(context),
            ),
          )
        : (text != null
            ? AutoSizeText(
                text!,
                maxLines: 1,
                style: (textStyle ??
                        context.textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ))
                    .copyWith(color: _resolvedForeground(context)),
              )
            : (child ?? const SizedBox.shrink()));

    if (type == ButtonType.secondary) {
      final ButtonStyle? base = Theme.of(context).outlinedButtonTheme.style;

      final Color normalFg = foregroundColor ?? AppColors.primary;
      final Color disabledFg =
          disabledForegroundColor ?? AppColors.primary.withOpacity(0.5);

      final ButtonStyle style = (base ?? const ButtonStyle()).copyWith(
        minimumSize:
            minimumSize != null ? WidgetStatePropertyAll(minimumSize!) : null,
        padding: padding != null ? WidgetStatePropertyAll(padding!) : null,
        shape: borderRadius != null
            ? WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: borderRadius!),
              )
            : null,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabledFg;
          return normalFg;
        }),
        side: (borderColor != null || borderWidth != null)
            ? WidgetStatePropertyAll(
                BorderSide(
                  color: borderColor ?? AppColors.primary,
                  width: borderWidth ?? 1.2,
                ),
              )
            : null,
      );

      return OutlinedButton(onPressed: onPressed, style: style, child: content);
    }

    final ButtonStyle? base = Theme.of(context).elevatedButtonTheme.style;

    final Color normalBg = backgroundColor ??
        (type == ButtonType.danger ? AppColors.error : null) ??
        AppColors.primary;

    final Color disabledBg = disabledBackgroundColor ??
        (type == ButtonType.danger
            ? AppColors.error.withOpacity(0.25)
            : AppColors.darkTextSecondary);

    final Color normalFg = foregroundColor ??
        (type == ButtonType.danger ? Colors.white : null) ??
        Colors.white;

    final Color disabledFg = disabledForegroundColor ??
        (type == ButtonType.danger
            ? Colors.white.withOpacity(0.85)
            : Colors.white.withOpacity(0.85));

    final ButtonStyle style = (base ?? const ButtonStyle()).copyWith(
      minimumSize:
          minimumSize != null ? WidgetStatePropertyAll(minimumSize!) : null,
      padding: padding != null ? WidgetStatePropertyAll(padding!) : null,
      shape: borderRadius != null
          ? WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: borderRadius!),
            )
          : null,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledBg;
        return normalBg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        return normalFg;
      }),
    );

    return ElevatedButton(onPressed: onPressed, style: style, child: content);
  }

  Color _resolvedForeground(BuildContext context) {
    if (_isDisabled) {
      if (disabledForegroundColor != null) return disabledForegroundColor!;
      if (type == ButtonType.secondary)
        return AppColors.primary.withOpacity(0.5);
      return Colors.white.withOpacity(0.85);
    }

    if (foregroundColor != null) return foregroundColor!;
    if (type == ButtonType.secondary) return AppColors.primary;
    if (type == ButtonType.danger) return Colors.white;

    final Color? themeFg = Theme.of(
      context,
    ).elevatedButtonTheme.style?.foregroundColor?.resolve(<WidgetState>{});

    return themeFg ?? AppColors.textWhite;
  }
}
