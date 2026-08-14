import 'package:camera/camera.dart' as camera;

class SelfieInputImageRequest {
  const SelfieInputImageRequest({
    required this.controller,
    required this.image,
  });

  final camera.CameraController controller;
  final camera.CameraImage image;
}
