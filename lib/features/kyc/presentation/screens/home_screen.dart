import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';

import '../steps/verification_flow/document_capture_step.dart';

class KycHomeScreen extends StatelessWidget {
  const KycHomeScreen({super.key});

  static const String path = '/kyc';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
      ),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your identity in 3 steps',
              style: context.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'We will capture your ID document and a live selfie, then process '
              'the verification securely on the server.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s24),
            _StepCard(
              index: '01',
              title: 'Document capture',
              subtitle: 'Take a clear photo of your ID card.',
            ),
            const SizedBox(height: AppSpacing.s12),
            _StepCard(
              index: '02',
              title: 'Selfie + liveness',
              subtitle: 'Follow the on-screen prompts.',
            ),
            const SizedBox(height: AppSpacing.s12),
            _StepCard(
              index: '03',
              title: 'Secure verification',
              subtitle: 'We process everything on the backend.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: 'Start Verification',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DocumentCaptureStep(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String index;
  final String title;
  final String subtitle;

  const _StepCard({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.padH16V12,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s4),
                Text(subtitle, style: context.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
