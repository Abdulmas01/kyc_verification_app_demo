import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kyc_verification_app_demo/core/network/dio_client.dart';
import 'package:kyc_verification_app_demo/core/network/endpoints.dart';

import '../models/start_session_request.dart';
import '../models/start_session_response.dart';
import '../models/upload_response.dart';
import '../models/upload_verification_request.dart';
import '../models/fetch_result_request.dart';
import '../../domain/models/verification_result.dart';

abstract class KycRemoteDataSourceBase {
  Future<StartSessionResponse> startSession(StartSessionRequest request);

  Future<UploadResponse> uploadVerification(UploadVerificationRequest request);

  Future<VerificationResult> fetchResult(FetchResultRequest request);
}

class KycRemoteDataSource implements KycRemoteDataSourceBase {
  final DioClient _dioClient;

  KycRemoteDataSource(this._dioClient);

  @override
  Future<StartSessionResponse> startSession(StartSessionRequest request) async {
    final response = await _dioClient.post(
      Endpoints.verifyStart,
      data: request.toJson(),
      cancelToken: request.cancelToken?.dioToken,
    );

    return StartSessionResponse.fromJson(response.data);
  }

  @override
  Future<UploadResponse> uploadVerification(
    UploadVerificationRequest request,
  ) async {
    final formData = FormData.fromMap({
      'session_token': request.sessionToken,
      'document_image': await MultipartFile.fromFile(
        request.documentImage.path,
        filename: 'document.jpg',
      ),
      'selfie_image': await MultipartFile.fromFile(
        request.selfieImage.path,
        filename: 'selfie.jpg',
      ),
    });

    final response = await _dioClient.post(
      Endpoints.verifyUpload,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: request.onSendProgress,
      cancelToken: request.cancelToken?.dioToken,
    );

    return UploadResponse.fromJson(response.data);
  }

  @override
  Future<VerificationResult> fetchResult(FetchResultRequest request) async {
    final response = await _dioClient.get(
      Endpoints.verifyResult(request.sessionId),
      cancelToken: request.cancelToken?.dioToken,
    );
    if (response.data is Map<String, dynamic>) {
      return VerificationResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    if (response.data is Map) {
      return VerificationResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw FlutterError('Unexpected response format');
  }
}
