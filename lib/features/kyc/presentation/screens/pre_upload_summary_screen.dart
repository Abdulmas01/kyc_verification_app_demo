import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/core/extension/context_extention.dart';
import 'package:kyc_verification_app_demo/core/platform/debug_share_channel.dart';
import 'package:kyc_verification_app_demo/core/theme/app_spacing.dart';
import 'package:kyc_verification_app_demo/core/widget/button_widget.dart';
import 'package:kyc_verification_app_demo/features/kyc/data/services/device_diagnostics_service.dart';
import 'package:kyc_verification_app_demo/features/kyc/data/services/face_embedding_match_service.dart';
import 'package:kyc_verification_app_demo/features/kyc/data/services/thesis_report_exporter.dart';
import 'package:kyc_verification_app_demo/features/kyc/domain/models/face_embedding_match_request.dart';
import 'package:kyc_verification_app_demo/features/kyc/domain/models/kyc_capture_bundle.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/controllers/thesis_debug_report_notifier.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/controllers/thesis_diagnostics_provider.dart';
import 'package:kyc_verification_app_demo/features/kyc/presentation/steps/verification_flow/processing_step.dart';

class PreUploadSummaryScreen extends ConsumerStatefulWidget {
  const PreUploadSummaryScreen({
    super.key,
    required this.captureBundle,
  });

  final KycCaptureBundle captureBundle;

  @override
  ConsumerState<PreUploadSummaryScreen> createState() =>
      _PreUploadSummaryScreenState();
}

class _PreUploadSummaryScreenState
    extends ConsumerState<PreUploadSummaryScreen> {
  final DeviceDiagnosticsService _deviceDiagnosticsService =
      const DeviceDiagnosticsService();
  final FaceEmbeddingMatchService _faceEmbeddingMatchService =
      const FaceEmbeddingMatchService();

  bool _isPreparing = true;
  bool _isExporting = false;
  bool _didScheduleAutoExport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareLocalSummary();
    });
  }

  Future<void> _prepareLocalSummary() async {
    try {
      final reportNotifier = ref.read(thesisDebugReportProvider.notifier);
      final report = ref.read(thesisDebugReportProvider);
      if (report.deviceSnapshot.isEmpty) {
        final snapshot = await _deviceDiagnosticsService.collectSnapshot();
        reportNotifier.recordDeviceSnapshot(snapshot);
      }

      final selfiePath = widget.captureBundle.selfiePath;
      if (selfiePath != null && selfiePath.isNotEmpty) {
        await _runMobileFaceMatchDebug(
          documentPath: widget.captureBundle.documentPath,
          selfiePath: selfiePath,
        );
      }

      if (!mounted) return;
      final diagnostics = ref.read(thesisDiagnosticsProvider);
      final latestExport = ref.read(latestThesisReportExportProvider);
      if (diagnostics.autoExportReports &&
          !_didScheduleAutoExport &&
          latestExport?.stage != ThesisReportStage.preUploadLocalReview) {
        _didScheduleAutoExport = true;
        await _exportReport();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _runMobileFaceMatchDebug({
    required String documentPath,
    required String selfiePath,
  }) async {
    try {
      final result = await _faceEmbeddingMatchService.run(
        FaceEmbeddingMatchRequest(
          documentPath: documentPath,
          selfiePath: selfiePath,
        ),
      );

      if (result == null) {
        ref
            .read(thesisDebugReportProvider.notifier)
            .recordMobileFaceMatchUnavailable(
              'Face embedding asset is missing or could not be loaded.',
            );
        return;
      }

      ref
          .read(thesisDebugReportProvider.notifier)
          .recordMobileFaceMatchSuccess(result);
    } catch (error) {
      ref
          .read(thesisDebugReportProvider.notifier)
          .recordMobileFaceMatchUnavailable(error.toString());
    }
  }

  Future<void> _exportReport() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final report = ref.read(thesisDebugReportProvider);
      final exportResult = await ref.read(thesisReportExporterProvider).export(
            report,
            stage: ThesisReportStage.preUploadLocalReview,
          );
      ref.read(thesisDebugReportProvider.notifier).markExported(
            exportResult.directoryPath,
          );
      ref.read(latestThesisReportExportProvider.notifier).state = exportResult;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Local report exported to ${exportResult.directoryPath}'),
        ),
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
    await DebugShareChannel.shareText(
      subject: 'KYC Local Thesis Summary',
      text: summaryText,
    );
  }

  Future<void> _continueToBackend() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProcessingStep(captureBundle: widget.captureBundle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(thesisDebugReportProvider);
    final latestExport = ref.watch(latestThesisReportExportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local Summary')),
      body: Padding(
        padding: AppSpacing.pad16,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On-device summary before backend upload',
                      style: context.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'This captures local document, selfie, liveness, face match, and device diagnostics for your thesis before network verification starts.',
                      style: context.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    if (_isPreparing) const LinearProgressIndicator(),
                    const SizedBox(height: AppSpacing.s16),
                    _SectionCard(
                      title: 'Document',
                      lines: [
                        'Status: ${report.documentStatusMessage ?? 'N/A'}',
                        'Quality: ${report.documentQualityLabel ?? 'N/A'}',
                        'Confidence: ${_formatDouble(report.documentQualityConfidence)}',
                        'Avg inference: ${_formatDouble(report.documentAverageInferenceMs, suffix: ' ms')}',
                        'Samples: ${report.documentInferenceSamples}',
                        'Frame stride: ${report.documentFrameStride ?? 'N/A'}',
                        'Auto capture: ${report.documentAutoCaptureTriggered}',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _SectionCard(
                      title: 'Liveness',
                      lines: [
                        'Status: ${report.selfieStatusMessage ?? 'N/A'}',
                        'Completed: ${report.completedChallenges.isEmpty ? 'None' : report.completedChallenges.join(', ')}',
                        'Mobile shadow enabled: ${report.mobileLivenessShadowEnabled}',
                        'Mobile shadow score: ${_formatDouble(report.mobileLivenessShadowScore)}',
                        'Mobile shadow latency: ${_formatDouble(report.mobileLivenessShadowLatencyMs, suffix: ' ms')}',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _SectionCard(
                      title: 'Face Match',
                      lines: [
                        'Attempted: ${report.mobileFaceMatchAttempted}',
                        'Available: ${report.mobileFaceMatchAvailable}',
                        'Score: ${_formatDouble(report.mobileFaceMatchScore)}',
                        'Threshold: ${_formatDouble(report.mobileFaceMatchThreshold)}',
                        'Document latency: ${_formatDouble(report.mobileFaceMatchDocumentLatencyMs, suffix: ' ms')}',
                        'Selfie latency: ${_formatDouble(report.mobileFaceMatchSelfieLatencyMs, suffix: ' ms')}',
                        'Error: ${report.mobileFaceMatchError ?? 'None'}',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _SectionCard(
                      title: 'Device',
                      lines: report.deviceSnapshot.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .toList(),
                    ),
                    if (latestExport != null) ...[
                      const SizedBox(height: AppSpacing.s12),
                      _SectionCard(
                        title: 'Latest Export',
                        lines: [
                          'Stage: ${latestExport.stage.name}',
                          'Directory: ${latestExport.directoryPath}',
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isExporting ? null : _exportReport,
                    child: Text(
                        _isExporting ? 'Exporting...' : 'Export local report'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: ButtonWidget(
                    text: 'Continue',
                    enabled: !_isPreparing,
                    onTap: _isPreparing ? null : _continueToBackend,
                  ),
                ),
              ],
            ),
            if (latestExport != null) ...[
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _shareSummary(latestExport.summaryText),
                  child: const Text('Share local summary'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDouble(double? value, {String suffix = ''}) {
    if (value == null) return 'N/A';
    return '${value.toStringAsFixed(3)}$suffix';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

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
          Text(title, style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: context.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
