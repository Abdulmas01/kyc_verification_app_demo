import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/models/kyc_capture_config.dart';

class DocumentCaptureRequest {
  const DocumentCaptureRequest({
    required this.controller,
    required this.objectDetector,
    required this.captureConfig,
  });

  final CameraController controller;
  final ObjectDetector objectDetector;
  final DocumentCaptureConfig captureConfig;
}
