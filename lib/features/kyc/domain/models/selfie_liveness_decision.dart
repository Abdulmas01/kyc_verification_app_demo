enum SelfieLivenessDecisionType {
  waitForBetterLighting,
  promptBlink,
  blinkCompleted,
  promptTurnLeft,
  turnLeftCompleted,
  promptTurnRight,
  turnRightCompleted,
  promptLookStraight,
  readyToCapture,
  complete,
}

class SelfieLivenessDecision {
  const SelfieLivenessDecision({
    required this.type,
    this.statusMessage,
    this.helperMessage,
    this.completedChallengeKey,
    this.primesBlink = false,
    this.resetsBlink = false,
  });

  final SelfieLivenessDecisionType type;
  final String? statusMessage;
  final String? helperMessage;
  final String? completedChallengeKey;
  final bool primesBlink;
  final bool resetsBlink;

  bool get shouldCapture => type == SelfieLivenessDecisionType.readyToCapture;
}
