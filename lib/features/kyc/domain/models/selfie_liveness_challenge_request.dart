import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../presentation/models/kyc_capture_config.dart';
import '../../presentation/models/selfie_capture_ui_state.dart';

class SelfieLivenessChallengeRequest {
  const SelfieLivenessChallengeRequest({
    required this.face,
    required this.uiState,
    required this.config,
    required this.blinkPrimed,
  });

  final Face face;
  final SelfieCaptureUiState uiState;
  final SelfieLivenessConfig config;
  final bool blinkPrimed;
}
