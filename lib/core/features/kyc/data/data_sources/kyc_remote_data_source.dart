import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kyc_verification_app_demo/core/network/dio_client.dart';
import 'package:kyc_verification_app_demo/core/network/endpoints.dart';

import '../models/start_session_response.dart';
import '../models/upload_response.dart';
import '../../domain/models/verification_result.dart';

class KycRemoteDataSource {
  final DioClient _dioClient;

  KycRemoteDataSource(this._dioClient);

  Future<StartSessionResponse> startSession({
    required String appVersion,
    required String deviceOs,
  }) async {
    final response = await _dioClient.post(
      Endpoints.verifyStart,
      data: {
        'app_version': appVersion,
        'device_os': deviceOs,
        'model_version': 'v1.0.0',
      },
    );

    return StartSessionResponse.fromJson(response.data);
  }

  Future<UploadResponse> uploadVerification({
    required String sessionToken,
    required File documentImage,
    required File selfieImage,
  }) async {
    final formData = FormData.fromMap({
      'session_token': sessionToken,
      'document_image': await MultipartFile.fromFile(
        documentImage.path,
        filename: 'document.jpg',
      ),
      'selfie_image': await MultipartFile.fromFile(
        selfieImage.path,
        filename: 'selfie.jpg',
      ),
    });

    final response = await _dioClient.post(
      Endpoints.verifyUpload,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return UploadResponse.fromJson(response.data);
  }

  Future<VerificationResult> fetchResult(String sessionId) async {
    final response = await _dioClient.get(Endpoints.verifyResult(sessionId));
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
