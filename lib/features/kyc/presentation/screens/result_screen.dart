import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/platform/debug_share_channel.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:kyc_verification_app_demo/features/kyc/data/services/thesis_report_exporter.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/controllers/thesis_debug_report_notifier.dart';

import '../../domain/models/verification_result.dart';
import '../extensions/verification_decision_ui_ext.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.result});

  static const String path = '/kyc/result';

  final VerificationResult result;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final decisionUi = widget.result.decision;
    final latestExport = ref.watch(latestThesisReportExportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s24),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: decisionUi.color.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        decisionUi.icon,
                        size: 52,
                        color: decisionUi.color,
                      ),
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
                    _RiskScoreChip(score: widget.result.riskScore),
                    const SizedBox(height: AppSpacing.s16),
                    if (widget.result.reasonCodes.isNotEmpty)
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: widget.result.reasonCodes
                            .map((code) => Chip(label: Text(code)))
                            .toList(),
                      ),
                    if (kDebugMode) ...[
                      const SizedBox(height: AppSpacing.s24),
                      _DebugSignalsCard(result: widget.result),
                      const SizedBox(height: AppSpacing.s16),
                      _DebugExportCard(
                        latestExport: latestExport,
                        isExporting: _isExporting,
                        onExport: _exportReport,
                        onShare: latestExport == null
                            ? null
                            : () => _shareSummary(latestExport.summaryText),
                        onCopyPath: latestExport == null
                            ? null
                            : () => _copyExportPath(latestExport.directoryPath),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ButtonWidget(
                text: 'Done',
                onTap: () {
                  ref.read(thesisDebugReportProvider.notifier).reset();
                  ref.read(latestThesisReportExportProvider.notifier).state =
                      null;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final report = ref.read(thesisDebugReportProvider);
      final exportResult =
          await ref.read(thesisReportExporterProvider).export(report);
      ref.read(thesisDebugReportProvider.notifier).markExported(
            exportResult.directoryPath,
          );
      ref.read(latestThesisReportExportProvider.notifier).state = exportResult;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Report exported to ${exportResult.directoryPath}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _shareSummary(String summaryText) async {
    try {
      await DebugShareChannel.shareText(
        subject: 'KYC Thesis Debug Report',
        text: summaryText,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sharing is not available on this device.')),
      );
    }
  }

  Future<void> _copyExportPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export path copied.')),
    );
  }
}

class _RiskScoreChip extends StatelessWidget {
  const _RiskScoreChip({required this.score});

  final double score;

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

class _DebugSignalsCard extends StatelessWidget {
  const _DebugSignalsCard({required this.result});

  final VerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.pad16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debug Signals', style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              _SignalChip(label: 'Session', value: result.sessionId),
              _SignalChip(
                  label: 'OCR', value: _formatDouble(result.ocrConfidence)),
              _SignalChip(
                label: 'Field Valid',
                value: _formatDouble(result.fieldValidScore),
              ),
              _SignalChip(
                label: 'Face Match',
                value: _formatDouble(result.faceSimilarity),
              ),
              _SignalChip(
                label: 'Face Area',
                value: _formatDouble(result.faceAreaRatio),
              ),
              _SignalChip(
                label: 'Liveness',
                value: _formatDouble(result.livenessScore),
              ),
              _SignalChip(
                label: 'Quality',
                value: _formatDouble(result.qualityScore),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDouble(double? value) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(3);
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _DebugExportCard extends StatelessWidget {
  const _DebugExportCard({
    required this.latestExport,
    required this.isExporting,
    required this.onExport,
    required this.onShare,
    required this.onCopyPath,
  });

  final ThesisReportExportResult? latestExport;
  final bool isExporting;
  final Future<void> Function() onExport;
  final VoidCallback? onShare;
  final VoidCallback? onCopyPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.pad16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thesis Export', style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Debug builds can export a structured report bundle with backend payload and capture artifacts.',
            style: context.textTheme.bodySmall,
          ),
          if (latestExport != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              latestExport!.directoryPath,
              style: context.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            width: double.infinity,
            child: ButtonWidget(
              text: isExporting ? 'Exporting...' : 'Export thesis report',
              enabled: !isExporting,
              onTap: isExporting ? null : onExport,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onShare,
                  child: const Text('Share summary'),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCopyPath,
                  child: const Text('Copy path'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
