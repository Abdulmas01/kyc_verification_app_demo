import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/platform/debug_export_channel.dart';
import '../../presentation/models/thesis_debug_report.dart';

enum ThesisReportStage { preUploadLocalReview, finalBackendResult }

class ThesisReportExportResult {
  const ThesisReportExportResult({
    required this.stage,
    required this.directoryPath,
    required this.reportMarkdownPath,
    required this.reportJsonPath,
    required this.shareableFilePaths,
    required this.summaryText,
  });

  final ThesisReportStage stage;
  final String directoryPath;
  final String reportMarkdownPath;
  final String reportJsonPath;
  final List<String> shareableFilePaths;
  final String summaryText;
}

class ThesisReportExporter {
  Future<ThesisReportExportResult> export(
    ThesisDebugReport report, {
    required ThesisReportStage stage,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final localExportDirectory = Directory(
      '${documentsDirectory.path}/kyc_thesis_reports/${report.runId}/${stage.name}',
    );
    final capturesDirectory = Directory(
      '${localExportDirectory.path}/supporting/captures',
    );
    final backendDirectory = Directory(
      '${localExportDirectory.path}/supporting/backend',
    );

    await capturesDirectory.create(recursive: true);
    await backendDirectory.create(recursive: true);

    String? copiedDocumentPath;
    String? copiedSelfiePath;
    String? copiedDocumentPortraitPath;
    String? copiedDocumentQualityGuideCropPath;
    String? copiedDocumentQualityModelInputPath;
    String? copiedDocumentQualityMetadataPath;
    copiedDocumentPath = await _copyIfPresent(
      sourcePath: report.normalizedDocumentPath ?? report.documentPath,
      targetPath: '${capturesDirectory.path}/document.jpg',
    );
    copiedSelfiePath = await _copyIfPresent(
      sourcePath: report.selfiePath,
      targetPath: '${capturesDirectory.path}/selfie.jpg',
    );
    copiedDocumentPortraitPath = await _copyIfPresent(
      sourcePath: report.mobileFaceMatchPortraitPath,
      targetPath: '${capturesDirectory.path}/document_portrait.jpg',
    );
    copiedDocumentQualityGuideCropPath = await _copyIfPresent(
      sourcePath: report.documentQualityDebugFullFramePath,
      targetPath: '${capturesDirectory.path}/document_quality_guide_crop.jpg',
    );
    copiedDocumentQualityModelInputPath = await _copyIfPresent(
      sourcePath: report.documentQualityDebugModelInputPath,
      targetPath:
          '${capturesDirectory.path}/document_quality_model_input_224.jpg',
    );
    copiedDocumentQualityMetadataPath = await _copyIfPresent(
      sourcePath: report.documentQualityDebugMetadataPath,
      targetPath: '${capturesDirectory.path}/document_quality_metadata.json',
    );

    final backendPayloadPath = '${backendDirectory.path}/result_payload.json';
    if (report.result != null) {
      await File(backendPayloadPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(report.result!.toJson()),
      );
    }

    final supportingFiles = {
      'captures': {
        'document': copiedDocumentPath,
        'selfie': copiedSelfiePath,
        'document_portrait': copiedDocumentPortraitPath,
        'document_quality_guide_crop': copiedDocumentQualityGuideCropPath,
        'document_quality_model_input': copiedDocumentQualityModelInputPath,
        'document_quality_metadata': copiedDocumentQualityMetadataPath,
      },
      'backend': {
        'result_payload': report.result != null ? backendPayloadPath : null,
      },
    };

    final jsonPath = '${localExportDirectory.path}/report.json';
    final markdownPath = '${localExportDirectory.path}/report.md';

    final shareableFilePaths = <String>[
      if (copiedDocumentPath != null) copiedDocumentPath,
      if (copiedSelfiePath != null) copiedSelfiePath,
      if (copiedDocumentPortraitPath != null) copiedDocumentPortraitPath,
      if (copiedDocumentQualityGuideCropPath != null)
        copiedDocumentQualityGuideCropPath,
      if (copiedDocumentQualityModelInputPath != null)
        copiedDocumentQualityModelInputPath,
      if (copiedDocumentQualityMetadataPath != null)
        copiedDocumentQualityMetadataPath,
      if (report.result != null) backendPayloadPath,
    ];

    final downloadExport = await _exportToDownloadsIfSupported(
      runId: report.runId,
      stage: stage,
      localFilePaths: shareableFilePaths,
    );
    final finalDirectoryPath = downloadExport?.directoryPath.isNotEmpty == true
        ? downloadExport!.directoryPath
        : localExportDirectory.path;

    final summaryText =
        _buildSummary(report, stage, finalDirectoryPath, supportingFiles);
    final jsonBody = report.toJson(
      exportDirectoryPath: finalDirectoryPath,
      supportingFiles: supportingFiles,
      reportStage: stage.name,
    );

    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonBody),
    );
    await File(markdownPath).writeAsString(summaryText);

    final shareableFilesWithReport = <String>[
      markdownPath,
      jsonPath,
      ...shareableFilePaths,
    ];

    return ThesisReportExportResult(
      stage: stage,
      directoryPath: finalDirectoryPath,
      reportMarkdownPath: markdownPath,
      reportJsonPath: jsonPath,
      shareableFilePaths: shareableFilesWithReport,
      summaryText: summaryText,
    );
  }

  Future<DebugExportChannelResult?> _exportToDownloadsIfSupported({
    required String runId,
    required ThesisReportStage stage,
    required List<String> localFilePaths,
  }) async {
    return DebugExportChannel.exportFilesToDownloads(
      directoryName: 'kyc_thesis_reports/$runId/${stage.name}',
      sourcePaths: localFilePaths,
    );
  }

  Future<String?> _copyIfPresent({
    required String? sourcePath,
    required String targetPath,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final file = File(sourcePath);
    if (!await file.exists()) return null;
    await file.copy(targetPath);
    return targetPath;
  }

  String _buildSummary(
    ThesisDebugReport report,
    ThesisReportStage stage,
    String exportDirectory,
    Map<String, dynamic> supportingFiles,
  ) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final result = report.result;
    final lines = <String>[
      '# KYC Thesis Debug Report',
      '',
      '## Run Metadata',
      '- Run ID: `${report.runId}`',
      '- Report Stage: `${stage.name}`',
      '- Started At: ${formatter.format(report.startedAt)}',
      '- Export Directory: `$exportDirectory`',
      '',
      '## Device',
      '```json',
      const JsonEncoder.withIndent('  ').convert(report.deviceSnapshot),
      '```',
      '',
      '## Document Capture',
      '- Status: ${report.documentStatusMessage ?? 'N/A'}',
      '- Quality Label: ${report.documentQualityLabel ?? 'N/A'}',
      '- Quality Confidence: ${_formatDouble(report.documentQualityConfidence)}',
      '- Quality Accepted: ${report.documentQualityAccepted?.toString() ?? 'N/A'}',
      '- Average Inference: ${_formatDouble(report.documentAverageInferenceMs, suffix: ' ms')}',
      '- Inference Samples: ${report.documentInferenceSamples}',
      '- Adaptive Frame Stride: ${report.documentFrameStride ?? 'N/A'}',
      '- Auto Capture Triggered: ${report.documentAutoCaptureTriggered}',
      '- Document Detected: ${report.documentDetected}',
      '- Last Error: ${report.documentError ?? 'None'}',
      '- Quality Debug Sample: ${report.documentQualityDebugSampleDirectoryPath ?? 'Not captured'}',
      '',
      '## Selfie And Liveness',
      '- Status: ${report.selfieStatusMessage ?? 'N/A'}',
      '- Face Detected: ${report.selfieFaceDetected}',
      '- Completed Challenges: ${report.completedChallenges.isEmpty ? 'None' : report.completedChallenges.join(', ')}',
      '- Redo Count: ${report.selfieRedoCount}',
      '- Timeout Count: ${report.selfieTimeoutCount}',
      '- Mobile Shadow Enabled: ${report.mobileLivenessShadowEnabled}',
      '- Mobile Shadow Attempted: ${report.mobileLivenessShadowAttempted}',
      '- Mobile Shadow Available: ${report.mobileLivenessShadowAvailable}',
      '- Mobile Shadow Score: ${_formatDouble(report.mobileLivenessShadowScore)}',
      '- Mobile Shadow Threshold: ${_formatDouble(report.mobileLivenessShadowThreshold)}',
      '- Mobile Shadow Interpretation: ${_formatMobileShadowInterpretation(report)}',
      '- Mobile Shadow Latency: ${_formatDouble(report.mobileLivenessShadowLatencyMs, suffix: ' ms')}',
      '- Mobile Shadow Error: ${report.mobileLivenessShadowError ?? 'None'}',
      '- Mobile Face Match Attempted: ${report.mobileFaceMatchAttempted}',
      '- Mobile Face Match Available: ${report.mobileFaceMatchAvailable}',
      '- Mobile Face Match Score: ${_formatDouble(report.mobileFaceMatchScore)}',
      '- Mobile Face Match Threshold: ${_formatDouble(report.mobileFaceMatchThreshold)}',
      '- Mobile Face Match Interpretation: ${_formatFaceMatchInterpretation(report)}',
      '- Mobile Face Match Document Latency: ${_formatDouble(report.mobileFaceMatchDocumentLatencyMs, suffix: ' ms')}',
      '- Mobile Face Match Selfie Latency: ${_formatDouble(report.mobileFaceMatchSelfieLatencyMs, suffix: ' ms')}',
      '- Mobile Face Match Error: ${report.mobileFaceMatchError ?? 'None'}',
      '- Last Error: ${report.selfieError ?? 'None'}',
      '',
      '## Processing',
      '- Backend Session ID: ${report.backendSessionId ?? result?.sessionId ?? 'N/A'}',
      '- Upload Progress Peak: ${_formatDouble(report.uploadProgressPeak * 100, suffix: '%')}',
      '- Upload Duration: ${_formatNullableInt(report.uploadDurationMs, suffix: ' ms')}',
      '- Total Verification Duration: ${_formatNullableInt(report.totalVerificationDurationMs, suffix: ' ms')}',
      '- Poll Attempts: ${report.pollAttempts}',
      '- API Error: ${report.apiError ?? 'None'}',
      '',
      '## Final Result',
      '- Decision: ${result == null ? 'N/A' : result.toJson()['decision']}',
      '- Status: ${result?.status ?? 'N/A'}',
      '- Session Token: ${result?.sessionToken ?? 'N/A'}',
      '- Risk Score: ${_formatDouble(result?.riskScore)}',
      '- Reason Codes: ${result == null || result.reasonCodes.isEmpty ? 'None' : result.reasonCodes.join(', ')}',
      '- OCR Confidence: ${_formatDouble(result?.ocrConfidence)}',
      '- Field Valid Score: ${_formatDouble(result?.fieldValidScore)}',
      '- Extracted ID Number: ${result?.extractedIdNumber.isNotEmpty == true ? result!.extractedIdNumber : 'N/A'}',
      '- Extracted Full Name: ${result?.extractedFullName.isNotEmpty == true ? result!.extractedFullName : 'N/A'}',
      '- Extracted Date Of Birth: ${result?.extractedDateOfBirth ?? 'N/A'}',
      '- Extracted Expiry Date: ${result?.extractedExpiryDate ?? 'N/A'}',
      '- Failure Code: ${result?.failureCode.isNotEmpty == true ? result!.failureCode : 'N/A'}',
      '- Failure Message: ${result?.failureMessage.isNotEmpty == true ? result!.failureMessage : 'N/A'}',
      '',
      '## Supporting Files',
      '- `report.json`',
      '- `report.md`',
      '- `supporting/captures/document.jpg`: ${supportingFiles['captures']['document'] ?? 'Not exported'}',
      '- `supporting/captures/selfie.jpg`: ${supportingFiles['captures']['selfie'] ?? 'Not exported'}',
      '- `supporting/captures/document_portrait.jpg`: ${supportingFiles['captures']['document_portrait'] ?? 'Not exported'}',
      '- `supporting/captures/document_quality_guide_crop.jpg`: ${supportingFiles['captures']['document_quality_guide_crop'] ?? 'Not exported'}',
      '- `supporting/captures/document_quality_model_input_224.jpg`: ${supportingFiles['captures']['document_quality_model_input'] ?? 'Not exported'}',
      '- `supporting/captures/document_quality_metadata.json`: ${supportingFiles['captures']['document_quality_metadata'] ?? 'Not exported'}',
      '- `supporting/backend/result_payload.json`: ${supportingFiles['backend']['result_payload'] ?? 'Not exported'}',
      '',
      '## Config Snapshot',
      '```json',
      const JsonEncoder.withIndent('  ').convert({
        'document': report.documentConfig,
        'selfie_liveness': report.selfieConfig,
      }),
      '```',
    ];
    return lines.join('\n');
  }

  String _formatDouble(double? value, {String suffix = ''}) {
    if (value == null) return 'N/A';
    return '${value.toStringAsFixed(3)}$suffix';
  }

  String _formatNullableInt(int? value, {String suffix = ''}) {
    if (value == null) return 'N/A';
    return '$value$suffix';
  }

  String _formatMobileShadowInterpretation(ThesisDebugReport report) {
    final score = report.mobileLivenessShadowScore;
    final threshold = report.mobileLivenessShadowThreshold;
    if (score == null || threshold == null || threshold <= 0) return 'N/A';

    final ratio = score / threshold;
    if (ratio >= 1) return 'meets threshold';
    if (ratio >= 0.85) return 'borderline below threshold';
    if (ratio >= 0.5) return 'clearly below threshold';
    return 'very far below threshold';
  }

  String _formatFaceMatchInterpretation(ThesisDebugReport report) {
    final score = report.mobileFaceMatchScore;
    final threshold = report.mobileFaceMatchThreshold;
    if (score == null || threshold == null || threshold <= 0) return 'N/A';

    final ratio = score / threshold;
    if (ratio >= 1) return 'meets threshold';
    if (ratio >= 0.9) return 'near threshold';
    if (ratio >= 0.7) return 'below threshold';
    return 'far below threshold';
  }
}

final thesisReportExporterProvider = Provider<ThesisReportExporter>((ref) {
  return ThesisReportExporter();
});

final latestThesisReportExportProvider =
    StateProvider<ThesisReportExportResult?>((ref) => null);
