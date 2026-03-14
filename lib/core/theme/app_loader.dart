import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppLoader extends StatelessWidget {
  final double height;
  final double width;
  final double strokeWidth;
  final Color? color;
  final String? label;
  final TextStyle? labelStyle;

  const AppLoader({
    super.key,
    this.height = 50,
    this.width = 50,
    this.strokeWidth = 4.0,
    this.color,
    this.label,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.getTextColor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  height: height,
                  width: width,
                  child: CircularProgressIndicator(
                    strokeWidth: strokeWidth,
                    valueColor: AlwaysStoppedAnimation(themeColor),
                  ),
                ),
              ),
            );
          },
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: labelStyle ??
                TextStyle(
                  color: themeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }
}
