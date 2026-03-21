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
import '../../../domain/models/verification_result.dart';

class ProcessingStep extends ConsumerStatefulWidget {
  const ProcessingStep({super.key, required this.captureBundle});

  static const String path = '/kyc/processing';

  final KycCaptureBundle captureBundle;

  @override
  ConsumerState<ProcessingStep> createState() => _ProcessingStepState();
}

class _ProcessingStepState extends ConsumerState<ProcessingStep> {
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  Future<void> _startVerification() async {
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
    final verificationAsync = ref.watch(verificationApiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Padding(
        padding: AppSpacing.pad16,
        child: verificationAsync.when(
          data: (result) {
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
          },
          loading: () => _buildLoading(context),
          error: (e, _) => _buildError(context, e.toString()),
        ),
      ),
    );
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

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Verification failed', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s8),
          Text(message, style: context.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.s16),
          ButtonWidget(
            text: 'Retry',
            onTap: _startVerification,
          ),
        ],
      ),
    );
  }
}
