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
  final int completedChallenges;
  final int totalChallenges;
  final SelfieLivenessChallenge currentChallenge;
  final String? errorMessage;

  const SelfieCaptureUiState({
    required this.statusMessage,
    required this.isDetecting,
    required this.isFaceDetected,
    required this.isAutoCapturing,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.currentChallenge,
    this.errorMessage,
  });

  factory SelfieCaptureUiState.initial() {
    return const SelfieCaptureUiState(
      statusMessage: 'Blink naturally to begin the liveness check.',
      isDetecting: false,
      isFaceDetected: false,
      isAutoCapturing: false,
      completedChallenges: 0,
      totalChallenges: 3,
      currentChallenge: SelfieLivenessChallenge.blink,
      errorMessage: null,
    );
  }

  SelfieCaptureUiState copyWith({
    String? statusMessage,
    bool? isDetecting,
    bool? isFaceDetected,
    bool? isAutoCapturing,
    int? completedChallenges,
    int? totalChallenges,
    SelfieLivenessChallenge? currentChallenge,
    Object? errorMessage = _sentinel,
  }) {
    return SelfieCaptureUiState(
      statusMessage: statusMessage ?? this.statusMessage,
      isDetecting: isDetecting ?? this.isDetecting,
      isFaceDetected: isFaceDetected ?? this.isFaceDetected,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      currentChallenge: currentChallenge ?? this.currentChallenge,
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
