import '../data_sources/kyc_remote_data_source.dart';
import '../models/fetch_result_request.dart';
import '../models/start_session_request.dart';
import '../models/start_session_response.dart';
import '../models/upload_response.dart';
import '../models/upload_verification_request.dart';
import '../../domain/models/verification_result.dart';
import 'kyc_repository.dart';

class KycRepositoryImpl implements KycRepository {
  final KycRemoteDataSourceBase _remote;

  KycRepositoryImpl(this._remote);

  @override
  Future<StartSessionResponse> startSession(StartSessionRequest request) {
    return _remote.startSession(request);
  }

  @override
  Future<UploadResponse> uploadVerification(UploadVerificationRequest request) {
    return _remote.uploadVerification(request);
  }

  @override
  Future<VerificationResult> fetchResult(FetchResultRequest request) {
    return _remote.fetchResult(request);
  }
}
