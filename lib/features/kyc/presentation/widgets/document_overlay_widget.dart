import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/theme/app_colors.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/models/kyc_capture_config.dart';

class DocumentOverlayWidget extends StatelessWidget {
  const DocumentOverlayWidget({
    super.key,
    this.visible = true,
    this.captureConfig = const DocumentCaptureConfig.balanced(),
  });

  final bool visible;
  final DocumentCaptureConfig captureConfig;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.expand();
    }
    return CustomPaint(
      painter: _DocumentOverlayPainter(captureConfig: captureConfig),
      child: const SizedBox.expand(),
    );
  }
}

class _DocumentOverlayPainter extends CustomPainter {
  const _DocumentOverlayPainter({
    required this.captureConfig,
  });

  final DocumentCaptureConfig captureConfig;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * captureConfig.guideWidthFactor,
      height: size.width *
          captureConfig.guideWidthFactor *
          captureConfig.guideAspectRatio,
    );

    final overlayPaint = Paint()..color = AppColors.overlayLight;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          ),
      ),
      overlayPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..color = AppColors.accentGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    _drawCorner(
      canvas,
      rect.topLeft,
      Offset(rect.left + 24, rect.top),
      Offset(rect.left, rect.top + 24),
    );
    _drawCorner(
      canvas,
      rect.topRight,
      Offset(rect.right - 24, rect.top),
      Offset(rect.right, rect.top + 24),
    );
    _drawCorner(
      canvas,
      rect.bottomLeft,
      Offset(rect.left + 24, rect.bottom),
      Offset(rect.left, rect.bottom - 24),
    );
    _drawCorner(
      canvas,
      rect.bottomRight,
      Offset(rect.right - 24, rect.bottom),
      Offset(rect.right, rect.bottom - 24),
    );
  }

  void _drawCorner(Canvas canvas, Offset corner, Offset end1, Offset end2) {
    final paint = Paint()
      ..color = AppColors.accentGreen
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(corner, end1, paint);
    canvas.drawLine(corner, end2, paint);
  }

  @override
  bool shouldRepaint(covariant _DocumentOverlayPainter oldDelegate) {
    return oldDelegate.captureConfig != captureConfig;
  }
}
