import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/network/dio_client.dart';

import '../../data/data_sources/kyc_remote_data_source.dart';
import '../../data/repositories/kyc_repository.dart';
import '../../data/repositories/kyc_repository_impl.dart';
import '../../domain/models/verification_result.dart';
import '../../domain/enums/verification_decision.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final dioClient = ref.watch(dioProvider);
  final remote = KycRemoteDataSource(dioClient);
  return KycRepositoryImpl(remote);
});

class VerificationApiNotifier
    extends AutoDisposeNotifier<AsyncValue<VerificationResult?>> {
  @override
  AsyncValue<VerificationResult?> build() => const AsyncData(null);

  Future<void> verify({
    required File documentImage,
    required File selfieImage,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(kycRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final session = await repo.startSession(
        appVersion: '1.0.0',
        deviceOs: Platform.isIOS ? 'ios' : 'android',
      );

      final upload = await repo.uploadVerification(
        sessionToken: session.sessionToken,
        documentImage: documentImage,
        selfieImage: selfieImage,
      );

      // Simple poll loop (max 8 tries)
      VerificationResult? lastResult;
      for (var i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 1200));
        lastResult = await repo.fetchResult(upload.sessionId);
      }

      return lastResult ??
          VerificationResult(
            sessionId: upload.sessionId,
            decision: VerificationDecision.manualReview,
            riskScore: 0.5,
            reasonCodes: const ['PROCESSING_TIMEOUT'],
          );
    });
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final verificationApiProvider = AutoDisposeNotifierProvider<
    VerificationApiNotifier, AsyncValue<VerificationResult?>>(
  VerificationApiNotifier.new,
);
