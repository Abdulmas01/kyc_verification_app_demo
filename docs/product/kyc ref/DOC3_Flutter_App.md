# KYC Thesis — Document 3: Flutter Mobile App
## Build-Ready Implementation Plan

> **Prerequisites:** Document 1 exports are needed before wiring real models.
> Use mock scores during Flutter development — swap real TFLite models in Phase 6.
> The API contracts from Document 2 are what this app is built around.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter 3.19+ (Dart) | Cross-platform, TFLite support, camera plugins |
| State Management | Riverpod 2.0 | Predictable, testable, no boilerplate |
| Camera | camera 0.10+ | Fine-grained frame access needed for quality scoring |
| ML Inference | tflite_flutter 0.10+ | Run .tflite models on-device |
| Face Detection | google_mlkit_face_detection | Free, on-device, accurate |
| OCR (optional UX) | google_mlkit_text_recognition | Optional on-device pre-fill only |
| HTTP | dio 5.4 | Interceptors for auth headers, retry logic |
| Local Storage | flutter_secure_storage | Store session token + API key securely |
| Navigation | go_router 13.0 | Declarative, deep-link ready |
| Image Processing | image 4.1 | Crop, resize, normalize images in Dart |

---

## Project Structure

```
kyc_flutter/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # App root, router setup
│   │
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart     # Dio setup + interceptors
│   │   │   ├── kyc_api.dart        # All API calls
│   │   │   └── models/             # Request/Response DTOs
│   │   │       ├── session_models.dart
│   │   │       └── verification_models.dart
│   │   ├── ml/
│   │   │   ├── model_loader.dart   # Load TFLite models at startup
│   │   │   ├── quality_model.dart  # Doc quality inference
│   │   │   ├── face_model.dart     # Face embedding inference
│   │   │   └── liveness_model.dart # Liveness inference
│   │   ├── camera/
│   │   │   ├── camera_service.dart # Camera stream management
│   │   │   └── frame_processor.dart# Real-time frame analysis
│   │   ├── image/
│   │   │   ├── image_utils.dart    # Crop, warp, normalize
│   │   │   └── face_aligner.dart   # Align face to 112x112
│   │   ├── extension/              # Context, Theme, and Enum extensions
│   │   │   ├── build_context_extension.dart
│   │   │   └── enum_helper.dart
│   │   ├── widget/                 # Shared UI components
│   │   │   ├── kyc_button.dart
│   │   │   └── step_progress_bar.dart
│   │   └── constants.dart
│   │
│   ├── core/features/
│   │   └── kyc/
│   │       ├── data/
│   │       │   ├── data_sources/
│   │       │   ├── repositories/
│   │       │   └── services/
│   │       ├── domain/             # Models, Enums, Business rules
│   │       │   ├── enums/
│   │       │   └── models/
│   │       └── presentation/
│   │           ├── controllers/
│   │           │   ├── verification_ui_state_notifier.dart
│   │           │   └── verification_api_notifier.dart
│   │           ├── screens/
│   │           │   ├── home_screen.dart
│   │           │   └── result_screen.dart
│   │           ├── steps/          # Multi-step flows
│   │           │   └── verification_flow/
│   │           │       ├── document_capture_step.dart
│   │           │       ├── selfie_capture_step.dart
│   │           │       └── processing_step.dart
│   │           └── widgets/
│   │               ├── camera_preview_widget.dart
│   │               ├── document_overlay_widget.dart
│   │               └── quality_indicator_widget.dart
│   │
│   ├── assets/
│   │   └── models/
│   │       ├── doc_quality.tflite      # From Document 1 exports
│   │       ├── face_embedder.tflite
│   │       └── liveness.tflite
│   │
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml
│   ├── ios/
│   │   └── Runner/Info.plist
│   └── pubspec.yaml
```

---

## Step 1 — pubspec.yaml

```yaml
name: kyc_flutter
description: AI-Based KYC Verification System

environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.4.10
  riverpod_annotation: ^2.3.4

  # Camera
  camera: ^0.10.5

  # ML Kit (on-device, free)
  google_mlkit_face_detection: ^0.9.0
  google_mlkit_text_recognition: ^0.11.0 # optional UX pre-fill only

  # TFLite inference
  tflite_flutter: ^0.10.4

  # Networking
  dio: ^5.4.1

  # Image processing
  image: ^4.1.7

  # Storage
  flutter_secure_storage: ^9.0.0

  # Navigation
  go_router: ^13.2.0

  # Utilities
  permission_handler: ^11.3.0
  path_provider: ^2.1.2
  logger: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.8
  flutter_lints: ^3.0.0

flutter:
  assets:
    - assets/models/doc_quality.tflite
    - assets/models/face_embedder.tflite
    - assets/models/liveness.tflite
```

---

## Step 2 — Permissions Setup

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Camera is required for identity document capture and selfie verification</string>
```

---

## Step 3 — ML Model Loader

Load all TFLite models once at app startup. Same pattern as Django's `apps.py`.

```dart
// lib/core/ml/model_loader.dart

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

class ModelLoader {
  static Interpreter? _qualityModel;
  static Interpreter? _faceModel;
  static Interpreter? _livenessModel;

  static bool _loaded = false;

  static Future<void> loadAll() async {
    if (_loaded) return;

    final options = InterpreterOptions()..threads = 2;

    _qualityModel = await Interpreter.fromAsset(
      'assets/models/doc_quality.tflite',
      options: options,
    );
    _faceModel = await Interpreter.fromAsset(
      'assets/models/face_embedder.tflite',
      options: options,
    );
    _livenessModel = await Interpreter.fromAsset(
      'assets/models/liveness.tflite',
      options: options,
    );

    _loaded = true;
  }

  static Interpreter get qualityModel {
    if (_qualityModel == null) throw StateError('Models not loaded. Call loadAll() first.');
    return _qualityModel!;
  }

  static Interpreter get faceModel => _faceModel!;
  static Interpreter get livenessModel => _livenessModel!;
}
```

```dart
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ml/model_loader.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load all ML models before app renders
  await ModelLoader.loadAll();

  runApp(
    const ProviderScope(
      child: KYCApp(),
    ),
  );
}
```

---

## Step 4 — API Client

```dart
// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'https://your-backend.com/api/v1';
  static final _storage = FlutterSecureStorage();

  static Dio get instance {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth interceptor — attaches API key to every request
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final apiKey = await _storage.read(key: 'api_key');
        if (apiKey != null) {
          options.headers['Authorization'] = 'ApiKey $apiKey';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Log error for debugging
        print('API Error: ${error.response?.statusCode} ${error.requestOptions.path}');
        handler.next(error);
      },
    ));

    return dio;
  }
}
```

```dart
// lib/core/network/kyc_api.dart

import 'package:dio/dio.dart';
import 'api_client.dart';
import 'models/session_models.dart';
import 'models/verification_models.dart';

class KycApi {
  final Dio _dio = ApiClient.instance;

  /// Step 1: Start a new verification session
  Future<StartSessionResponse> startSession({
    required String appVersion,
    required String deviceOs,
  }) async {
    final response = await _dio.post('/verify/start/', data: {
      'app_version': appVersion,
      'device_os': deviceOs,
      'model_version': 'v1.0.0',
    });
    return StartSessionResponse.fromJson(response.data);
  }

  /// Step 2: Upload images (server-authoritative inference)
  Future<UploadResponse> uploadVerification({
    required String sessionToken,
    required List<int> documentImageBytes,
    required List<int> selfieImageBytes,
  }) async {
    final formData = FormData.fromMap({
      'session_token': sessionToken,
      'document_image': MultipartFile.fromBytes(
        documentImageBytes,
        filename: 'document.jpg',
      ),
      'selfie_image': MultipartFile.fromBytes(
        selfieImageBytes,
        filename: 'selfie.jpg',
      ),
    });
    final response = await _dio.post('/verify/upload/', data: formData);
    return UploadResponse.fromJson(response.data);
  }

  /// Step 3: Poll for result
  Future<VerificationResult> getResult({
    required String sessionId,
  }) async {
    final response = await _dio.get('/verify/$sessionId/');
    return VerificationResult.fromJson(response.data);
  }
}
```

```dart
// lib/core/network/models/verification_models.dart

class UploadResponse {
  final String sessionId;
  final int estimatedWaitMs;

  const UploadResponse({
    required this.sessionId,
    required this.estimatedWaitMs,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) =>
    UploadResponse(
      sessionId: json['session_id'],
      estimatedWaitMs: json['estimated_wait_ms'] ?? 1500,
    );
}

class VerificationResult {
  final String sessionId;
  final String decision;       // "ACCEPT" | "REJECT" | "MANUAL_REVIEW"
  final double riskScore;
  final List<String> reasonCodes;
  final String timestamp;

  const VerificationResult({
    required this.sessionId,
    required this.decision,
    required this.riskScore,
    required this.reasonCodes,
    required this.timestamp,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) =>
    VerificationResult(
      sessionId:   json['session_id'],
      decision:    json['decision'],
      riskScore:   (json['risk_score'] as num).toDouble(),
      reasonCodes: List<String>.from(json['reason_codes'] ?? []),
      timestamp:   json['timestamp'],
    );

  bool get isAccepted => decision == 'ACCEPT';
  bool get isRejected => decision == 'REJECT';
  bool get needsReview => decision == 'MANUAL_REVIEW';
}
```

---

## Step 5 — Document Quality Model Inference

```dart
// lib/core/ml/quality_model.dart

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_loader.dart';

enum DocumentQuality { good, blurry, glare, dark, noDocument }

class QualityModelResult {
  final DocumentQuality quality;
  final double confidence;
  final List<double> probabilities;

  const QualityModelResult({
    required this.quality,
    required this.confidence,
    required this.probabilities,
  });

  bool get isGoodForCapture => quality == DocumentQuality.good && confidence > 0.75;

  String get feedbackMessage {
    switch (quality) {
      case DocumentQuality.good:       return 'Hold still...';
      case DocumentQuality.blurry:     return 'Hold the camera steady';
      case DocumentQuality.glare:      return 'Reduce glare — move away from light';
      case DocumentQuality.dark:       return 'Move to a brighter area';
      case DocumentQuality.noDocument: return 'Position your document in the frame';
    }
  }
}

class QualityModel {
  static const List<String> _labels = [
    'GOOD', 'BLURRY', 'GLARE', 'DARK', 'NO_DOCUMENT'
  ];

  /// Run inference on a single camera frame.
  /// Called on every frame in the live capture loop — must be fast.
  static Future<QualityModelResult> predict(img.Image frame) async {
    // Resize to model input: 224x224
    final resized = img.copyResize(frame, width: 224, height: 224);

    // Normalize to [0, 1] and convert to float32 tensor [1, 224, 224, 3]
    final input = _imageToTensor(resized);
    final output = List.filled(5, 0.0).reshape([1, 5]);

    ModelLoader.qualityModel.run(input, output);

    final probs = List<double>.from(output[0]);
    final maxIdx = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));

    return QualityModelResult(
      quality:       DocumentQuality.values[maxIdx],
      confidence:    probs[maxIdx],
      probabilities: probs,
    );
  }

  static List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return [
      List.generate(224, (y) =>
        List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })
      )
    ];
  }
}
```

---

## Step 6 — Face Embedding Model Inference

```dart
// lib/core/ml/face_model.dart

import 'dart:math';
import 'package:image/image.dart' as img;
import 'model_loader.dart';

class FaceModel {

  /// Extract 128-dim embedding from an aligned 112x112 face image.
  static List<double> embed(img.Image alignedFace) {
    final resized = img.copyResize(alignedFace, width: 112, height: 112);
    final input = _faceToTensor(resized);
    final output = List.filled(128, 0.0).reshape([1, 128]);

    ModelLoader.faceModel.run(input, output);

    final embedding = List<double>.from(output[0]);
    return _l2Normalize(embedding);
  }

  /// Compare two embeddings — returns 0.0 to 1.0
  /// Higher = more similar = same person
  static double cosineSimilarity(List<double> emb1, List<double> emb2) {
    double dot = 0, norm1 = 0, norm2 = 0;
    for (int i = 0; i < emb1.length; i++) {
      dot   += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }
    if (norm1 == 0 || norm2 == 0) return 0.0;
    return dot / (sqrt(norm1) * sqrt(norm2));
  }

  static List<double> _l2Normalize(List<double> v) {
    final norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    return norm > 0 ? v.map((x) => x / norm).toList() : v;
  }

  /// Input: float32 [1, 112, 112, 3] normalized to [-1, 1]
  static List<List<List<List<double>>>> _faceToTensor(img.Image image) {
    return [
      List.generate(112, (y) =>
        List.generate(112, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (pixel.r / 127.5) - 1.0,   // normalize to [-1, 1]
            (pixel.g / 127.5) - 1.0,
            (pixel.b / 127.5) - 1.0,
          ];
        })
      )
    ];
  }
}
```

---

## Step 7 — Liveness Model Inference

```dart
// lib/core/ml/liveness_model.dart

import 'package:image/image.dart' as img;
import 'model_loader.dart';

class LivenessModel {

  /// Predict liveness from the best selfie frame.
  /// Returns 0.0 (spoof) to 1.0 (live).
  static double predict(img.Image frame) {
    final resized = img.copyResize(frame, width: 128, height: 128);
    final input = _frameToTensor(resized);
    final output = List.filled(2, 0.0).reshape([1, 2]);

    ModelLoader.livenessModel.run(input, output);

    // output[0][1] = probability of LIVE class
    return (output[0] as List)[1].toDouble();
  }

  /// For multi-frame analysis: average liveness score across N frames.
  /// More robust than single-frame prediction.
  static double predictMultiFrame(List<img.Image> frames) {
    if (frames.isEmpty) return 0.0;
    final scores = frames.map(predict).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static List<List<List<List<double>>>> _frameToTensor(img.Image image) {
    return [
      List.generate(128, (y) =>
        List.generate(128, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })
      )
    ];
  }
}
```

---

## Step 8 — App Router

```dart
// lib/core/features/kyc/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
// ...
```

```dart
// lib/app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/features/kyc/presentation/screens/home_screen.dart';
import 'core/features/kyc/presentation/steps/verification_flow/document_capture_step.dart';
import 'core/features/kyc/presentation/steps/verification_flow/selfie_capture_step.dart';
import 'core/features/kyc/presentation/steps/verification_flow/processing_step.dart';
import 'core/features/kyc/presentation/screens/result_screen.dart';

final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/verify/document',
      builder: (_, __) => const DocumentCaptureStep(),
    ),
    GoRoute(
      path: '/verify/selfie',
      builder: (_, __) => const SelfieCaptureStep(),
    ),
    GoRoute(
      path: '/verify/processing',
      builder: (_, __) => const ProcessingStep(),
    ),
    GoRoute(
      path: '/verify/result',
      builder: (context, state) {
        final result = state.extra as VerificationResult;
        return ResultScreen(result: result);
      },
    ),
  ],
);

class KYCApp extends StatelessWidget {
  const KYCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KYC Verify',
      theme: _buildTheme(),
      routerConfig: _router,
    );
  }

  ThemeData _buildTheme() => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF1A56DB),
    fontFamily: 'Inter',
  );
}
```

---

## Step 9 — Document Capture Screen

This is the most complex screen — real-time camera feed with live quality scoring on every frame.

```dart
// lib/core/features/kyc/presentation/steps/verification_flow/document_capture_step.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../controllers/verification_ui_state_notifier.dart';
import '../widgets/quality_indicator_widget.dart';
import '../widgets/document_overlay_widget.dart';

class DocumentCaptureStep extends ConsumerStatefulWidget {
  const DocumentCaptureStep({super.key});

  @override
  ConsumerState<DocumentCaptureStep> createState() =>
      _DocumentCaptureStepState();
}

class _DocumentCaptureStepState
    extends ConsumerState<DocumentCaptureStep> {

  late CameraController _cameraController;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController.initialize();
    setState(() => _cameraReady = true);

    // Start processing every frame
    _cameraController.startImageStream((CameraImage frame) {
      ref.read(verificationUiStateNotifierProvider.notifier)
         .processDocumentFrame(frame);
    });
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentCaptureControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Your ID Document',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Camera view with overlay
            Expanded(
              child: Stack(
                children: [
                  if (_cameraReady)
                    Center(child: CameraPreview(_cameraController)),

                  // Document boundary overlay (rectangular guide)
                  const DocumentOverlayWidget(),

                  // Quality indicator (top of camera)
                  Positioned(
                    top: 16, left: 16, right: 16,
                    child: QualityIndicatorWidget(
                      message: state.qualityFeedback,
                      isGood: state.isQualityGood,
                    ),
                  ),

                  // Auto-capture progress ring
                  if (state.isQualityGood)
                    Positioned(
                      bottom: 24,
                      left: 0, right: 0,
                      child: Center(
                        child: _CapturRingIndicator(
                          progress: state.captureProgress,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Instruction text
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.isQualityGood
                    ? 'Great! Hold still — capturing...'
                    : state.qualityFeedback,
                style: TextStyle(
                  color: state.isQualityGood ? Colors.green : Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturRingIndicator extends StatelessWidget {
  final double progress;
  const _CapturRingIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, height: 72,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 4,
        color: Colors.green,
        backgroundColor: Colors.white24,
      ),
    );
  }
}
```

```dart
// lib/features/document_capture/document_capture_controller.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../core/ml/quality_model.dart';
import '../../core/camera/frame_processor.dart';

class DocumentCaptureState {
  final String qualityFeedback;
  final bool isQualityGood;
  final double captureProgress;     // 0.0 - 1.0 for auto-capture ring
  final img.Image? capturedImage;
  final bool isCaptured;

  const DocumentCaptureState({
    this.qualityFeedback = 'Position your document in the frame',
    this.isQualityGood = false,
    this.captureProgress = 0.0,
    this.capturedImage,
    this.isCaptured = false,
  });

  DocumentCaptureState copyWith({
    String? qualityFeedback,
    bool? isQualityGood,
    double? captureProgress,
    img.Image? capturedImage,
    bool? isCaptured,
  }) => DocumentCaptureState(
    qualityFeedback: qualityFeedback ?? this.qualityFeedback,
    isQualityGood:   isQualityGood   ?? this.isQualityGood,
    captureProgress: captureProgress ?? this.captureProgress,
    capturedImage:   capturedImage   ?? this.capturedImage,
    isCaptured:      isCaptured      ?? this.isCaptured,
  );
}

class DocumentCaptureController
    extends StateNotifier<DocumentCaptureState> {

  DocumentCaptureController() : super(const DocumentCaptureState());

  // Auto-capture: hold good quality for 1.5 seconds
  int _goodFrameCount = 0;
  static const int _framesNeededForCapture = 45; // ~1.5s at 30fps
  bool _isProcessing = false;
  bool _captured = false;

  Future<void> processFrame(CameraImage cameraImage) async {
    if (_isProcessing || _captured) return;
    _isProcessing = true;

    try {
      // Convert camera frame to image
      final frame = FrameProcessor.convertCameraImage(cameraImage);
      if (frame == null) return;

      // Run quality model
      final result = await QualityModel.predict(frame);

      if (result.isGoodForCapture) {
        _goodFrameCount++;
        final progress = _goodFrameCount / _framesNeededForCapture;

        if (_goodFrameCount >= _framesNeededForCapture) {
          // Auto-capture triggered
          _captured = true;
          state = state.copyWith(
            isQualityGood:   true,
            captureProgress: 1.0,
            capturedImage:   frame,
            isCaptured:      true,
            qualityFeedback: 'Document captured!',
          );
        } else {
          state = state.copyWith(
            isQualityGood:   true,
            captureProgress: progress,
            qualityFeedback: 'Hold still...',
          );
        }
      } else {
        // Reset progress if quality drops
        _goodFrameCount = 0;
        state = state.copyWith(
          isQualityGood:   false,
          captureProgress: 0.0,
          qualityFeedback: result.feedbackMessage,
        );
      }
    } finally {
      _isProcessing = false;
    }
  }
}

final documentCaptureControllerProvider =
    StateNotifierProvider<DocumentCaptureController, DocumentCaptureState>(
  (ref) => DocumentCaptureController(),
);
```

---

## Step 10 — Selfie Capture Screen (with Liveness)

```dart
// lib/features/selfie_capture/selfie_capture_controller.dart

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../core/ml/face_model.dart';
import '../../core/ml/liveness_model.dart';
import '../../core/image/face_aligner.dart';

enum LivenessChallenge { blink, turnLeft, turnRight, done }

class SelfieCaptureState {
  final String instruction;
  final LivenessChallenge currentChallenge;
  final bool isFaceDetected;
  final bool isChallengeComplete;
  final bool isCaptured;
  final double livenessScore;
  final List<double>? faceEmbedding;
  final double? faceSimilarity;

  const SelfieCaptureState({
    this.instruction = 'Position your face in the oval',
    this.currentChallenge = LivenessChallenge.blink,
    this.isFaceDetected = false,
    this.isChallengeComplete = false,
    this.isCaptured = false,
    this.livenessScore = 0.0,
    this.faceEmbedding,
    this.faceSimilarity,
  });

  SelfieCaptureState copyWith({
    String? instruction,
    LivenessChallenge? currentChallenge,
    bool? isFaceDetected,
    bool? isChallengeComplete,
    bool? isCaptured,
    double? livenessScore,
    List<double>? faceEmbedding,
    double? faceSimilarity,
  }) => SelfieCaptureState(
    instruction:          instruction          ?? this.instruction,
    currentChallenge:     currentChallenge     ?? this.currentChallenge,
    isFaceDetected:       isFaceDetected       ?? this.isFaceDetected,
    isChallengeComplete:  isChallengeComplete  ?? this.isChallengeComplete,
    isCaptured:           isCaptured           ?? this.isCaptured,
    livenessScore:        livenessScore        ?? this.livenessScore,
    faceEmbedding:        faceEmbedding        ?? this.faceEmbedding,
    faceSimilarity:       faceSimilarity       ?? this.faceSimilarity,
  );
}

class SelfieCaptureController extends StateNotifier<SelfieCaptureState> {
  SelfieCaptureController({required this.docFaceEmbedding})
      : super(const SelfieCaptureState());

  final List<double> docFaceEmbedding;

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,    // enables blink detection
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  final List<img.Image> _capturedFrames = [];
  bool _isProcessing = false;
  bool _blinkDetected = false;

  Future<void> processFrame(CameraImage cameraImage, img.Image frame) async {
    if (_isProcessing || state.isCaptured) return;
    _isProcessing = true;

    try {
      // Run ML Kit face detection
      final inputImage = _cameraImageToInputImage(cameraImage);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        state = state.copyWith(
          isFaceDetected: false,
          instruction: 'Position your face in the oval',
        );
        return;
      }

      final face = faces.first;
      state = state.copyWith(isFaceDetected: true);

      // Process liveness challenge
      switch (state.currentChallenge) {
        case LivenessChallenge.blink:
          await _processBlink(face, frame);
          break;
        case LivenessChallenge.turnLeft:
          await _processHeadTurn(face, frame, direction: 'left');
          break;
        case LivenessChallenge.turnRight:
          await _processHeadTurn(face, frame, direction: 'right');
          break;
        case LivenessChallenge.done:
          await _finalizeCapture(frame);
          break;
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processBlink(Face face, img.Image frame) async {
    final leftEyeOpen  = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

    if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2 && !_blinkDetected) {
      _blinkDetected = true;
      _capturedFrames.add(frame);
      state = state.copyWith(
        currentChallenge: LivenessChallenge.turnLeft,
        instruction: 'Now slowly turn your head LEFT',
      );
    } else if (!_blinkDetected) {
      state = state.copyWith(instruction: 'Please blink naturally');
    }
  }

  Future<void> _processHeadTurn(
    Face face, img.Image frame, {required String direction}) async {

    final yAngle = face.headEulerAngleY ?? 0;
    final threshold = direction == 'left' ? -20.0 : 20.0;
    final isTurned = direction == 'left' ? yAngle < threshold : yAngle > threshold;

    if (isTurned) {
      _capturedFrames.add(frame);
      if (direction == 'left') {
        state = state.copyWith(
          currentChallenge: LivenessChallenge.turnRight,
          instruction: 'Now turn your head RIGHT',
        );
      } else {
        state = state.copyWith(
          currentChallenge: LivenessChallenge.done,
          instruction: 'Look straight at the camera',
        );
      }
    }
  }

  Future<void> _finalizeCapture(img.Image frame) async {
    _capturedFrames.add(frame);

    // Liveness score from multi-frame analysis
    final livenessScore = LivenessModel.predictMultiFrame(_capturedFrames);

    // Extract face embedding from best frame
    final alignedFace = FaceAligner.align(frame);
    final selfieEmbedding = FaceModel.embed(alignedFace);

    // Compare with document face embedding
    final similarity = FaceModel.cosineSimilarity(
      selfieEmbedding, docFaceEmbedding
    );

    state = state.copyWith(
      isCaptured:          true,
      isChallengeComplete: true,
      livenessScore:       livenessScore,
      faceEmbedding:       selfieEmbedding,
      faceSimilarity:      similarity,
      instruction:         'Verification complete!',
    );
  }

  InputImage _cameraImageToInputImage(CameraImage image) {
    // Convert YUV420 camera frame to ML Kit InputImage
    final bytes = image.planes.map((p) => p.bytes).expand((x) => x).toList();
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(bytes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv_420_888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
```

---

## Step 11 — Processing Screen (Orchestrates Everything)

This screen runs after both captures are done — it calls the backend and shows progress.

```dart
// lib/features/processing/processing_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/kyc_api.dart';
import '../../core/api/models/verification_models.dart';
import '../../core/ml/quality_model.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum ProcessingStep {
  startingSession,
  computingScores,
  submittingToServer,
  done,
}

class ProcessingState {
  final ProcessingStep step;
  final String message;
  final bool hasError;
  final String? errorMessage;
  final VerificationResult? result;

  const ProcessingState({
    this.step = ProcessingStep.startingSession,
    this.message = 'Starting verification...',
    this.hasError = false,
    this.errorMessage,
    this.result,
  });

  ProcessingState copyWith({
    ProcessingStep? step,
    String? message,
    bool? hasError,
    String? errorMessage,
    VerificationResult? result,
  }) => ProcessingState(
    step:         step         ?? this.step,
    message:      message      ?? this.message,
    hasError:     hasError     ?? this.hasError,
    errorMessage: errorMessage ?? this.errorMessage,
    result:       result       ?? this.result,
  );
}

class ProcessingController extends StateNotifier<ProcessingState> {
  final KycApi _api = KycApi();
  final TextRecognizer _textRecognizer = TextRecognizer();

  ProcessingController() : super(const ProcessingState());

  /// Main orchestration method — runs the full verification pipeline.
  Future<void> runVerification({
    required CaptureData captureData,   // from previous screens
  }) async {
    try {
      // Step 1: Start session
      _update(ProcessingStep.startingSession, 'Starting verification session...');
      final session = await _api.startSession(
        appVersion: '1.0.0',
        deviceOs: 'android',
      );

      // Step 2: Upload images for server-authoritative inference
      _update(ProcessingStep.submittingToServer, 'Uploading images...');
      final upload = await _api.uploadVerification(
        sessionToken: session.sessionToken,
        documentImageBytes: captureData.documentImageBytes,
        selfieImageBytes: captureData.selfieImageBytes,
      );

      // Step 3: Poll for result
      _update(ProcessingStep.computingScores, 'Processing on server...');
      final result = await _api.getResult(sessionId: upload.sessionId);

      state = state.copyWith(
        step:    ProcessingStep.done,
        message: 'Done!',
        result:  result,
      );

    } catch (e) {
      state = state.copyWith(
        hasError:     true,
        errorMessage: 'Verification failed. Please try again.',
      );
    }
  }

  void _update(ProcessingStep step, String message) {
    state = state.copyWith(step: step, message: message);
  }
}
```

---

## Step 12 — Result Screen

```dart
// lib/features/result/result_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/models/verification_models.dart';

class ResultScreen extends StatelessWidget {
  final VerificationResult result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result Icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _resultColor.withOpacity(0.1),
                ),
                child: Icon(_resultIcon, size: 56, color: _resultColor),
              ),

              const SizedBox(height: 24),

              // Result Title
              Text(
                _resultTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _resultColor,
                ),
              ),

              const SizedBox(height: 12),

              // Result Subtitle
              Text(
                _resultSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 32),

              // Risk score chip (for debugging / thesis demo)
              if (result.riskScore > 0)
                Chip(
                  label: Text('Risk Score: ${result.riskScore.toStringAsFixed(2)}'),
                  backgroundColor: _resultColor.withOpacity(0.1),
                ),

              // Reason codes
              if (result.reasonCodes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: result.reasonCodes.map((code) =>
                    Chip(
                      label: Text(code, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.orange.shade50,
                    )
                  ).toList(),
                ),
              ],

              const Spacer(),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _resultColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done', fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _resultColor => switch (result.decision) {
    'ACCEPT'        => Colors.green,
    'REJECT'        => Colors.red,
    'MANUAL_REVIEW' => Colors.orange,
    _               => Colors.grey,
  };

  IconData get _resultIcon => switch (result.decision) {
    'ACCEPT'        => Icons.check_circle_outline,
    'REJECT'        => Icons.cancel_outlined,
    'MANUAL_REVIEW' => Icons.hourglass_empty,
    _               => Icons.help_outline,
  };

  String get _resultTitle => switch (result.decision) {
    'ACCEPT'        => 'Verified!',
    'REJECT'        => 'Verification Failed',
    'MANUAL_REVIEW' => 'Under Review',
    _               => 'Processing',
  };

  String get _resultSubtitle => switch (result.decision) {
    'ACCEPT'        => 'Your identity has been successfully verified.',
    'REJECT'        => 'We could not verify your identity. Please try again with a clearer document.',
    'MANUAL_REVIEW' => 'Your verification is being reviewed by our team. We\'ll notify you shortly.',
    _               => 'Please wait...',
  };
}
```

---

## Step 13 — Overlay Widgets

```dart
// lib/features/document_capture/widgets/document_overlay_widget.dart

import 'package:flutter/material.dart';

class DocumentOverlayWidget extends StatelessWidget {
  const DocumentOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DocumentOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DocumentOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width:  size.width * 0.85,
      height: size.width * 0.85 * 0.63,  // ID card aspect ratio
    );

    // Dark overlay outside the document rectangle
    final overlayPaint = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      overlayPaint,
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner markers
    _drawCorner(canvas, rect.topLeft, Offset(rect.left + 20, rect.top), Offset(rect.left, rect.top + 20));
    _drawCorner(canvas, rect.topRight, Offset(rect.right - 20, rect.top), Offset(rect.right, rect.top + 20));
    _drawCorner(canvas, rect.bottomLeft, Offset(rect.left + 20, rect.bottom), Offset(rect.left, rect.bottom - 20));
    _drawCorner(canvas, rect.bottomRight, Offset(rect.right - 20, rect.bottom), Offset(rect.right, rect.bottom - 20));
  }

  void _drawCorner(Canvas canvas, Offset corner, Offset end1, Offset end2) {
    final paint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(corner, end1, paint);
    canvas.drawLine(corner, end2, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
```

---

## Step 14 — Frame Processor Utility

```dart
// lib/core/camera/frame_processor.dart

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class FrameProcessor {
  /// Convert CameraImage (YUV420) to img.Image for ML inference.
  /// Skips frames to avoid overwhelming the ML pipeline.
  static int _frameSkip = 0;

  static img.Image? convertCameraImage(CameraImage cameraImage) {
    // Process every 3rd frame for quality scoring (performance)
    _frameSkip++;
    if (_frameSkip % 3 != 0) return null;

    try {
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      return _convertYuv420ToImage(
        cameraImage.width,
        cameraImage.height,
        yPlane.bytes,
        uPlane.bytes,
        vPlane.bytes,
        yPlane.bytesPerRow,
        uPlane.bytesPerRow,
      );
    } catch (_) {
      return null;
    }
  }

  static img.Image _convertYuv420ToImage(
    int width, int height,
    List<int> yBytes, List<int> uBytes, List<int> vBytes,
    int yRowStride, int uvRowStride,
  ) {
    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yp = yBytes[y * yRowStride + x];
        final up = uBytes[(y >> 1) * uvRowStride + (x >> 1)];
        final vp = vBytes[(y >> 1) * uvRowStride + (x >> 1)];

        int r = (yp + (1.370705 * (vp - 128))).clamp(0, 255).toInt();
        int g = (yp - (0.698001 * (vp - 128)) - (0.337633 * (up - 128))).clamp(0, 255).toInt();
        int b = (yp + (1.732446 * (up - 128))).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }
}
```

---

## Full KYC User Flow

```
HomeScreen
    ↓ [Start Verification]
DocumentCaptureScreen
    ↓ Camera stream → QualityModel → live feedback
    ↓ Auto-capture when GOOD quality held for 1.5s
SelfieCaptureScreen
    ↓ ML Kit Face Detection → blink + head turn challenges
ProcessingScreen
    ↓ POST /verify/start/ → session_token
    ↓ POST /verify/upload/ → document + selfie images
    ↓ GET /verify/{session_id}/ → decision
    ↓ Receive { decision, risk_score, reason_codes }
ResultScreen
    → ACCEPT ✅ / REJECT ❌ / MANUAL_REVIEW ⏳
```

---

## Build Timeline

| Task | Time Estimate |
|---|---|
| Project setup + pubspec + permissions | 0.5 day |
| ML model loader + TFLite wiring | 1 day |
| API client + models + DTOs | 1 day |
| Document capture screen + quality loop | 2–3 days |
| Selfie capture screen + liveness flow | 2–3 days |
| Processing screen + orchestration | 1–2 days |
| Result screen + router | 1 day |
| Overlay widgets + polish | 1–2 days |
| Testing on physical Android device | 2 days |
| **Total** | **~12–14 days** |

---

## Development Tips

**Build with mock scores first.** Before Document 1 models are trained, hardcode scores in the controller:
```dart
// Temporary mock while backend integration is pending
const mockResult = VerificationResult(
  sessionId: 'demo',
  decision: 'ACCEPT',
  riskScore: 0.08,
  reasonCodes: [],
  timestamp: '2026-03-01T12:00:00Z',
);
```
This lets you build and test the full UI/API flow weeks before the ML work is done.

**Test liveness on a physical device.** The camera stream does not work in the emulator — you need a real Android device for liveness and quality scoring.

**Frame processing on an isolate.** If quality scoring causes UI jank, move `QualityModel.predict()` to a Flutter isolate using `compute()`.

---

*Document 3 of 3 — All build documents complete.*
*Read order: DOC1 (AI Training) → DOC2 (Backend) → DOC3 (Flutter)*
