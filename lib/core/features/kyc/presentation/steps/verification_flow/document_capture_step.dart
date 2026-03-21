import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/utils/image_utils.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';

import '../../widgets/document_overlay_widget.dart';
import '../../../domain/models/kyc_capture_bundle.dart';
import 'selfie_capture_step.dart';

class DocumentCaptureStep extends StatefulWidget {
  const DocumentCaptureStep({super.key});

  static const String path = '/kyc/document';

  @override
  State<DocumentCaptureStep> createState() => _DocumentCaptureStepState();
}

class _DocumentCaptureStepState extends State<DocumentCaptureStep> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _isDetecting = false;
  bool _documentDetected = false;
  String _statusMessage = 'Align your ID inside the frame.';

  late final ObjectDetector _objectDetector;

  @override
  void initState() {
    super.initState();
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
    _initializeFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _objectDetector.close();
    super.dispose();
  }

  Future<void> _captureAndDetect() async {
    if (_controller == null || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _statusMessage = 'Detecting document...';
    });

    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final objects = await _objectDetector.processImage(inputImage);

      if (!mounted) return;
      final detectedObject = objects.isNotEmpty ? objects.first : null;
      if (detectedObject == null) {
        if (!mounted) return;
        setState(() {
          _documentDetected = false;
          _statusMessage = 'No document detected. Try again.';
        });
        return;
      }

      final normalized = await ImageUtils.normalizeDocumentImage(
        inputPath: file.path,
        boundingBox: detectedObject.boundingBox,
      );

      if (!mounted) return;
      setState(() {
        _documentDetected = true;
        _statusMessage = 'Document detected. Looks good!';
      });

      if (_documentDetected) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SelfieCaptureStep(
              captureBundle: KycCaptureBundle(documentPath: normalized.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Capture failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Capture'),
      ),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place your ID inside the frame',
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'We will guide you to get a clear, glare‑free capture.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(_statusMessage, style: context.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.s16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: FutureBuilder<void>(
                    future: _initializeFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_controller == null ||
                          !_controller!.value.isInitialized) {
                        return Center(
                          child: Text(
                            'Camera unavailable',
                            style: context.textTheme.bodySmall,
                          ),
                        );
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          const DocumentOverlayWidget(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: _isDetecting ? 'Detecting...' : 'Capture Document',
                enabled: !_isDetecting,
                onTap: _captureAndDetect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
