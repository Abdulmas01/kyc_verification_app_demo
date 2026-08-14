import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class DocumentCaptureRequest {
  const DocumentCaptureRequest({
    required this.controller,
    required this.objectDetector,
  });

  final CameraController controller;
  final ObjectDetector objectDetector;
}
