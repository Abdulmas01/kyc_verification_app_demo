import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_loader.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';

import '../../screens/result_screen.dart';
import '../../controllers/verification_api_notifier.dart';
import '../../../domain/models/kyc_capture_bundle.dart';
import '../../models/verification_api_state.dart';

class ProcessingStep extends ConsumerStatefulWidget {
  const ProcessingStep({super.key, required this.captureBundle});

  static const String path = '/kyc/processing';

  final KycCaptureBundle captureBundle;

  @override
  ConsumerState<ProcessingStep> createState() => _ProcessingStepState();
}

class _ProcessingStepState extends ConsumerState<ProcessingStep> {
  static const int maxAttempts = 3;
  bool _navigated = false;
  int _attempts = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  Future<void> _startVerification() async {
    if (_attempts >= maxAttempts) return;
    _attempts += 1;
    _navigated = false;
    final documentPath = widget.captureBundle.documentPath;
    final selfiePath = widget.captureBundle.selfiePath;
    if (selfiePath == null || selfiePath.isEmpty) {
      return;
    }
    await ref.read(verificationApiProvider.notifier).verify(
          documentImage: File(documentPath),
          selfieImage: File(selfiePath),
        );
  }

  @override
  Widget build(BuildContext context) {
    final apiState = ref.watch(verificationApiProvider);
    final canRetry = _attempts < maxAttempts;

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Padding(
        padding: AppSpacing.pad16,
        child: _buildBody(context, apiState, canRetry),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VerificationApiState apiState,
    bool canRetry,
  ) {
    switch (apiState.status) {
      case VerificationApiStatus.idle:
        return _buildLoading(context);
      case VerificationApiStatus.uploading:
        return _buildUploading(context, apiState.uploadProgress);
      case VerificationApiStatus.polling:
        return _buildPolling(context);
      case VerificationApiStatus.data:
        final result = apiState.result;
        if (result == null) {
          return _buildLoading(context);
        }

        if (!_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ResultScreen(result: result),
              ),
            );
          });
        }

        return _buildLoading(context);
      case VerificationApiStatus.timeout:
        return _buildTimeout(context, canRetry: canRetry);
      case VerificationApiStatus.error:
        return _buildError(
          context,
          apiState.error?.toString() ?? 'Unknown error',
          canRetry: canRetry,
        );
    }
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoader(label: 'Verifying your identity...'),
          const SizedBox(height: AppSpacing.s24),
          Text(
            'This usually takes a few seconds.',
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildUploading(BuildContext context, double progress) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoader(label: 'Uploading your documents...'),
          const SizedBox(height: AppSpacing.s16),
          LinearProgressIndicator(value: progress.clamp(0, 1)),
          const SizedBox(height: AppSpacing.s8),
          Text('$percent% uploaded', style: context.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildPolling(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoader(label: 'Checking results...'),
          const SizedBox(height: AppSpacing.s24),
          Text(
            'Hang tight — this may take a few seconds.',
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    String message, {
    required bool canRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Verification failed', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s8),
          Text(message, style: context.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.s16),
          ButtonWidget(
            text: canRetry ? 'Retry' : 'Retry limit reached',
            enabled: canRetry,
            onTap: canRetry ? _startVerification : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeout(BuildContext context, {required bool canRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Taking longer than expected',
              style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'The verification is still processing. Please try again.',
            style: context.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          ButtonWidget(
            text: canRetry ? 'Retry' : 'Retry limit reached',
            enabled: canRetry,
            onTap: canRetry ? _startVerification : null,
          ),
        ],
      ),
    );
  }
}
