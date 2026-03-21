import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class FrameProcessor {
  static int _frameSkip = 0;

  static img.Image? convert(CameraImage cameraImage) {
    _frameSkip++;
    if (_frameSkip % 3 != 0) return null;

    try {
      final width = cameraImage.width;
      final height = cameraImage.height;

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final img.Image image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yp = yPlane.bytes[y * yPlane.bytesPerRow + x];
          final int up =
              uPlane.bytes[(y >> 1) * uPlane.bytesPerRow + (x >> 1)];
          final int vp =
              vPlane.bytes[(y >> 1) * vPlane.bytesPerRow + (x >> 1)];

          int r = (yp + (1.370705 * (vp - 128))).clamp(0, 255).toInt();
          int g = (yp - (0.698001 * (vp - 128)) - (0.337633 * (up - 128)))
              .clamp(0, 255)
              .toInt();
          int b = (yp + (1.732446 * (up - 128))).clamp(0, 255).toInt();

          image.setPixelRgb(x, y, r, g, b);
        }
      }

      return image;
    } catch (_) {
      return null;
    }
  }
}
