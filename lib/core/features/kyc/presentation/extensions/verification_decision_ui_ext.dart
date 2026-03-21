import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../domain/enums/verification_decision.dart';

extension VerificationDecisionUiExt on VerificationDecision {
  String get title {
    switch (this) {
      case VerificationDecision.accept:
        return 'Verified!';
      case VerificationDecision.reject:
        return 'Verification Failed';
      case VerificationDecision.manualReview:
        return 'Under Review';
    }
  }

  String get subtitle {
    switch (this) {
      case VerificationDecision.accept:
        return 'Your identity has been successfully verified.';
      case VerificationDecision.reject:
        return 'We could not verify your identity. Please try again.';
      case VerificationDecision.manualReview:
        return 'Your verification is being reviewed by our team.';
    }
  }

  Color get color {
    switch (this) {
      case VerificationDecision.accept:
        return AppColors.statusSuccess;
      case VerificationDecision.reject:
        return AppColors.statusError;
      case VerificationDecision.manualReview:
        return AppColors.statusWarning;
    }
  }

  IconData get icon {
    switch (this) {
      case VerificationDecision.accept:
        return Icons.check_circle_outline;
      case VerificationDecision.reject:
        return Icons.cancel_outlined;
      case VerificationDecision.manualReview:
        return Icons.hourglass_empty;
    }
  }
}
