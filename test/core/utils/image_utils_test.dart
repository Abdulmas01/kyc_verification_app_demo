import 'package:flutter_test/flutter_test.dart';
import 'package:kyc_verification_app_demo/core/utils/image_utils.dart';

void main() {
  group('ImageUtils.calculateDocumentOutputSize', () {
    test('downscales the longest side while preserving aspect ratio', () {
      final output = ImageUtils.calculateDocumentOutputSize(
        width: 3200,
        height: 2016,
      );

      expect(output.width, 1600);
      expect(output.height, 1008);
    });

    test('does not upscale a smaller document crop', () {
      final output = ImageUtils.calculateDocumentOutputSize(
        width: 1200,
        height: 756,
      );

      expect(output.width, 1200);
      expect(output.height, 756);
    });

    test('preserves portrait aspect ratio', () {
      final output = ImageUtils.calculateDocumentOutputSize(
        width: 1200,
        height: 2400,
      );

      expect(output.width, 800);
      expect(output.height, 1600);
    });

    test('rejects invalid dimensions', () {
      expect(
        () => ImageUtils.calculateDocumentOutputSize(width: 0, height: 540),
        throwsArgumentError,
      );
    });
  });
}
