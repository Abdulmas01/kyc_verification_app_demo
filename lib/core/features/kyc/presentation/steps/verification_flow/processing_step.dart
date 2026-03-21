import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_loader.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';

import '../../screens/result_screen.dart';
import '../../../domain/models/verification_result.dart';

class ProcessingStep extends StatefulWidget {
  const ProcessingStep({super.key});

  static const String path = '/kyc/processing';

  @override
  State<ProcessingStep> createState() => _ProcessingStepState();
}

class _ProcessingStepState extends State<ProcessingStep> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _navigateToResult);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateToResult() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: VerificationResult.demo()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Center(
        child: Padding(
          padding: AppSpacing.pad16,
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
        ),
      ),
    );
  }
}
