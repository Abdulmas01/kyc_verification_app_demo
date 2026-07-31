enum SelfieLivenessChallenge {
  blink,
  turnLeft,
  turnRight,
  lookStraight,
  complete,
}

class SelfieCaptureUiState {
  static const Object _sentinel = Object();

  final String statusMessage;
  final bool isDetecting;
  final bool isFaceDetected;
  final bool isAutoCapturing;
  final bool isPermissionDenied;
  final bool isPermanentlyDenied;
  final bool isCameraReady;
  final int completedChallenges;
  final int totalChallenges;
  final SelfieLivenessChallenge currentChallenge;
  final String? cameraErrorMessage;
  final String? errorMessage;

  const SelfieCaptureUiState({
    required this.statusMessage,
    required this.isDetecting,
    required this.isFaceDetected,
    required this.isAutoCapturing,
    required this.isPermissionDenied,
    required this.isPermanentlyDenied,
    required this.isCameraReady,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.currentChallenge,
    this.cameraErrorMessage,
    this.errorMessage,
  });

  factory SelfieCaptureUiState.initial() {
    return const SelfieCaptureUiState(
      statusMessage: 'Blink naturally to begin the liveness check.',
      isDetecting: false,
      isFaceDetected: false,
      isAutoCapturing: false,
      isPermissionDenied: false,
      isPermanentlyDenied: false,
      isCameraReady: false,
      completedChallenges: 0,
      totalChallenges: 3,
      currentChallenge: SelfieLivenessChallenge.blink,
      cameraErrorMessage: null,
      errorMessage: null,
    );
  }

  SelfieCaptureUiState copyWith({
    String? statusMessage,
    bool? isDetecting,
    bool? isFaceDetected,
    bool? isAutoCapturing,
    bool? isPermissionDenied,
    bool? isPermanentlyDenied,
    bool? isCameraReady,
    int? completedChallenges,
    int? totalChallenges,
    SelfieLivenessChallenge? currentChallenge,
    Object? cameraErrorMessage = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return SelfieCaptureUiState(
      statusMessage: statusMessage ?? this.statusMessage,
      isDetecting: isDetecting ?? this.isDetecting,
      isFaceDetected: isFaceDetected ?? this.isFaceDetected,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      currentChallenge: currentChallenge ?? this.currentChallenge,
      cameraErrorMessage: cameraErrorMessage == _sentinel
          ? this.cameraErrorMessage
          : cameraErrorMessage as String?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  double get progress =>
      totalChallenges == 0 ? 0 : completedChallenges / totalChallenges;

  bool get isChallengeComplete =>
      currentChallenge == SelfieLivenessChallenge.complete;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}
