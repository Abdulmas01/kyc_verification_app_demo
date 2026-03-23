import '../models/start_session_request.dart';
import '../models/start_session_response.dart';
import '../models/fetch_result_request.dart';
import '../models/upload_response.dart';
import '../models/upload_verification_request.dart';
import '../../domain/models/verification_result.dart';

abstract class KycRepository {
  Future<StartSessionResponse> startSession(StartSessionRequest request);

  Future<UploadResponse> uploadVerification(UploadVerificationRequest request);

  Future<VerificationResult> fetchResult(FetchResultRequest request);
}
