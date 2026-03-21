import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';

import '../extensions/verification_decision_ui_ext.dart';
import '../../domain/models/verification_result.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  static const String path = '/kyc/result';

  final VerificationResult result;

  @override
  Widget build(BuildContext context) {
    final decisionUi = result.decision;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s24),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: decisionUi.color.withOpacity(0.12),
              ),
              child: Icon(decisionUi.icon, size: 52, color: decisionUi.color),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              decisionUi.title,
              style: context.textTheme.headlineMedium?.copyWith(
                color: decisionUi.color,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              decisionUi.subtitle,
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            _RiskScoreChip(score: result.riskScore),
            const SizedBox(height: AppSpacing.s16),
            if (result.reasonCodes.isNotEmpty)
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: result.reasonCodes
                    .map((code) => Chip(label: Text(code)))
                    .toList(),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: 'Done',
                onTap: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskScoreChip extends StatelessWidget {
  final double score;

  const _RiskScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        'Risk Score: ${score.toStringAsFixed(2)}',
        style: context.textTheme.bodySmall,
      ),
    );
  }
}
