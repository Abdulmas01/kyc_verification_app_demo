import '../../domain/models/selfie_liveness_decision.dart';
import '../../domain/models/selfie_liveness_challenge_request.dart';
import '../../presentation/models/selfie_capture_ui_state.dart';

class SelfieLivenessChallengeService {
  const SelfieLivenessChallengeService();

  SelfieLivenessDecision evaluate(SelfieLivenessChallengeRequest request) {
    final face = request.face;
    final uiState = request.uiState;
    final config = request.config;
    final blinkPrimed = request.blinkPrimed;
    switch (uiState.currentChallenge) {
      case SelfieLivenessChallenge.blink:
        final leftEyeOpen = face.leftEyeOpenProbability;
        final rightEyeOpen = face.rightEyeOpenProbability;
        if (leftEyeOpen == null || rightEyeOpen == null) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.waitForBetterLighting,
            statusMessage: 'Face not clear enough.',
          );
        }

        if (leftEyeOpen > config.blinkOpenThreshold &&
            rightEyeOpen > config.blinkOpenThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.promptBlink,
            statusMessage: 'Blink once.',
            primesBlink: true,
          );
        }

        if (blinkPrimed &&
            leftEyeOpen < config.blinkClosedThreshold &&
            rightEyeOpen < config.blinkClosedThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.blinkCompleted,
            completedChallengeKey: 'blink',
            resetsBlink: true,
          );
        }

        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.promptBlink,
          statusMessage: 'Blink once.',
        );
      case SelfieLivenessChallenge.turnLeft:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle < -config.headTurnThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.turnLeftCompleted,
            completedChallengeKey: 'turn_left',
          );
        }
        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.promptTurnLeft,
          statusMessage: 'Turn left.',
        );
      case SelfieLivenessChallenge.turnRight:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle > config.headTurnThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.turnRightCompleted,
            completedChallengeKey: 'turn_right',
          );
        }
        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.promptTurnRight,
          statusMessage: 'Turn right.',
        );
      case SelfieLivenessChallenge.lookStraight:
        final yAngle = face.headEulerAngleY ?? 0;
        if (yAngle.abs() <= config.lookStraightThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.readyToCapture,
            completedChallengeKey: 'look_straight',
          );
        }
        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.promptLookStraight,
          statusMessage: 'Look straight.',
        );
      case SelfieLivenessChallenge.complete:
        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.complete,
        );
    }
  }
}
