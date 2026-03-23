import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/network/dio_client.dart';
import 'package:kyc_verification_app_demo/core/network/request_cancel_token.dart';

import '../../data/data_sources/kyc_remote_data_source.dart';
import '../../data/models/fetch_result_request.dart';
import '../../data/models/start_session_request.dart';
import '../../data/models/upload_verification_request.dart';
import '../../data/repositories/kyc_repository.dart';
import '../../data/repositories/kyc_repository_impl.dart';
import '../../domain/models/verification_result.dart';
import '../models/verification_api_state.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final dioClient = ref.watch(dioProvider);
  final remote = KycRemoteDataSource(dioClient);
  return KycRepositoryImpl(remote);
});

class VerificationApiNotifier
    extends AutoDisposeNotifier<VerificationApiState> {
  static const int maxPollAttempts = 8;
  static const Duration pollInterval = Duration(milliseconds: 1200);

  RequestCancelToken? _cancelToken;

  @override
  VerificationApiState build() {
    ref.onDispose(_cancelActiveRequest);
    return const VerificationApiState.idle();
  }

  void _cancelActiveRequest() {
    _cancelToken?.cancel('KYC verification cancelled');
    _cancelToken = null;
  }

  Future<void> verify({
    required File documentImage,
    required File selfieImage,
  }) async {
    _cancelActiveRequest();
    _cancelToken = RequestCancelToken();
    state = const VerificationApiState.uploading(progress: 0);
    final repo = ref.read(kycRepositoryProvider);

    try {
      final session = await repo.startSession(
        StartSessionRequest(
          appVersion: '1.0.0',
          deviceOs: Platform.isIOS ? 'ios' : 'android',
          cancelToken: _cancelToken,
        ),
      );

      final upload = await repo.uploadVerification(
        UploadVerificationRequest(
          sessionToken: session.sessionToken,
          documentImage: documentImage,
          selfieImage: selfieImage,
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            final progress = sent / total;
            state = VerificationApiState.uploading(progress: progress);
          },
          cancelToken: _cancelToken,
        ),
      );

      state = const VerificationApiState.polling();

      // Simple poll loop (max attempts)
      VerificationResult? lastResult;
      for (var i = 0; i < maxPollAttempts; i++) {
        if (_cancelToken?.isCancelled ?? false) {
          state = const VerificationApiState.idle();
          return;
        }
        await Future.delayed(pollInterval);
        lastResult = await repo.fetchResult(
          FetchResultRequest(
            sessionId: upload.sessionId,
            cancelToken: _cancelToken,
          ),
        );
      }

      if (lastResult == null) {
        state = const VerificationApiState.timeout();
        return;
      }

      state = VerificationApiState.data(lastResult);
    } catch (e, st) {
      if (_cancelToken?.isCancelled ?? false) {
        state = const VerificationApiState.idle();
        return;
      }
      state = VerificationApiState.error(e, st);
    }
  }

  void clear() {
    _cancelActiveRequest();
    state = const VerificationApiState.idle();
  }
}

final verificationApiProvider =
    AutoDisposeNotifierProvider<VerificationApiNotifier, VerificationApiState>(
  VerificationApiNotifier.new,
);
