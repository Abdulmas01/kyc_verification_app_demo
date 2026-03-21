import 'dart:io';

import '../data_sources/kyc_remote_data_source.dart';
import '../models/start_session_response.dart';
import '../models/upload_response.dart';
import '../../domain/models/verification_result.dart';
import 'kyc_repository.dart';

class KycRepositoryImpl implements KycRepository {
  final KycRemoteDataSource _remote;

  KycRepositoryImpl(this._remote);

  @override
  Future<StartSessionResponse> startSession({
    required String appVersion,
    required String deviceOs,
  }) {
    return _remote.startSession(appVersion: appVersion, deviceOs: deviceOs);
  }

  @override
  Future<UploadResponse> uploadVerification({
    required String sessionToken,
    required File documentImage,
    required File selfieImage,
  }) {
    return _remote.uploadVerification(
      sessionToken: sessionToken,
      documentImage: documentImage,
      selfieImage: selfieImage,
    );
  }

  @override
  Future<VerificationResult> fetchResult(String sessionId) {
    return _remote.fetchResult(sessionId);
  }
}
