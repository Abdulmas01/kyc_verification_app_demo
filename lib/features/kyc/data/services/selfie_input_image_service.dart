import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class SelfieInputImageService {
  const SelfieInputImageService();

  InputImage? build(
      camera.CameraController controller, camera.CameraImage image) {
    final description = controller.description;
    final rotation = _inputImageRotationFromCamera(controller, description);
    if (rotation == null) return null;

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format != InputImageFormat.bgra8888) return null;

      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format!,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    if (!Platform.isAndroid) return null;
    final bytes = _androidCameraImageToNv21(image);
    if (bytes == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  Uint8List? _androidCameraImageToNv21(camera.CameraImage image) {
    if (image.planes.length != 3) {
      return null;
    }

    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = width * height;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final nv21 = Uint8List(ySize + (uvWidth * uvHeight * 2));

    var destIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(destIndex, destIndex + width, yPlane.bytes, rowStart);
      destIndex += width;
    }

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (var col = 0; col < uvWidth; col++) {
        nv21[destIndex++] = vPlane.bytes[vRowStart + (col * vPixelStride)];
        nv21[destIndex++] = uPlane.bytes[uRowStart + (col * uPixelStride)];
      }
    }

    return nv21;
  }

  InputImageRotation? _inputImageRotationFromCamera(
    camera.CameraController controller,
    camera.CameraDescription description,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(
          description.sensorOrientation);
    }

    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final rotationCompensation =
        orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;

    final adjustedRotation = description.lensDirection ==
            camera.CameraLensDirection.front
        ? (description.sensorOrientation + rotationCompensation) % 360
        : (description.sensorOrientation - rotationCompensation + 360) % 360;

    return InputImageRotationValue.fromRawValue(adjustedRotation);
  }
}
