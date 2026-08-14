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
            statusMessage: 'Keep your face well lit, then blink naturally.',
            helperMessage: 'Make sure your eyes are fully visible.',
          );
        }

        if (leftEyeOpen > config.blinkOpenThreshold &&
            rightEyeOpen > config.blinkOpenThreshold) {
          return const SelfieLivenessDecision(
            type: SelfieLivenessDecisionType.promptBlink,
            statusMessage: 'Blink naturally to continue.',
            helperMessage: 'We are waiting for one natural blink.',
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
          statusMessage: 'Blink naturally to continue.',
          helperMessage: 'We are waiting for one natural blink.',
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
          statusMessage: 'Slowly turn your head to the left.',
          helperMessage: 'Move just enough so your face angle changes.',
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
          statusMessage: 'Now turn your head to the right.',
          helperMessage: 'Keep your face inside the oval while turning.',
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
          statusMessage: 'Look straight at the camera and hold still.',
          helperMessage: 'We are capturing your final frame.',
        );
      case SelfieLivenessChallenge.complete:
        return const SelfieLivenessDecision(
          type: SelfieLivenessDecisionType.complete,
        );
    }
  }
}
