import 'dart:io';

import '../models/start_session_response.dart';
import '../models/upload_response.dart';
import '../../domain/models/verification_result.dart';

abstract class KycRepository {
  Future<StartSessionResponse> startSession({
    required String appVersion,
    required String deviceOs,
  });

  Future<UploadResponse> uploadVerification({
    required String sessionToken,
    required File documentImage,
    required File selfieImage,
  });

  Future<VerificationResult> fetchResult(String sessionId);
}
