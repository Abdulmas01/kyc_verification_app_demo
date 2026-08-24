import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/platform/debug_export_channel.dart';
import '../../../../core/ml/quality_isolate.dart';
import '../../../../core/ml/quality_model.dart';

class DocumentQualityDebugExportResult {
  const DocumentQualityDebugExportResult({
    required this.directoryPath,
    required this.metadataPath,
    required this.fullFramePath,
    required this.modelInputPath,
    required this.shareableFilePaths,
  });

  final String directoryPath;
  final String metadataPath;
  final String fullFramePath;
  final String modelInputPath;
  final List<String> shareableFilePaths;
}

class DocumentQualityDebugExporter {
  Future<DocumentQualityDebugExportResult> exportLiveSample({
    required String runId,
    required QualityResult quality,
    required DocumentQuality displayedGuidance,
    required String guidanceMessage,
    required double inferenceMs,
    required int frameNumber,
    required int frameStride,
    required Map<String, dynamic> documentConfig,
    required QualityDebugArtifacts debugArtifacts,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
    final exportDirectory = Directory(
      '${documentsDirectory.path}/quality_debug_exports/$runId/sample_$timestamp',
    );
    await exportDirectory.create(recursive: true);

    final fullFramePath = '${exportDirectory.path}/full_frame.jpg';
    final modelInputPath = '${exportDirectory.path}/model_input_224.jpg';
    final metadataPath = '${exportDirectory.path}/metadata.json';

    await File(fullFramePath).writeAsBytes(debugArtifacts.fullFrameJpeg);
    await File(modelInputPath).writeAsBytes(debugArtifacts.modelInputJpeg);

    final metadata = {
      'run_id': runId,
      'captured_at': DateTime.now().toIso8601String(),
      'frame_number': frameNumber,
      'frame_stride': frameStride,
      'inference_ms': inferenceMs,
      'raw_quality': quality.quality.name,
      'raw_confidence': quality.confidence,
      'guidance_quality': displayedGuidance.name,
      'guidance_message': guidanceMessage,
      'top_predictions': quality.topPredictionsSummary(),
      'probabilities': {
        for (var i = 0;
            i < quality.labels.length && i < quality.probabilities.length;
            i++)
          quality.labels[i]: quality.probabilities[i],
      },
      'frame_size': {
        'width': debugArtifacts.frameWidth,
        'height': debugArtifacts.frameHeight,
      },
      'model_input_size': {
        'width': debugArtifacts.modelWidth,
        'height': debugArtifacts.modelHeight,
      },
      'guide_crop_rect': {
        'left': debugArtifacts.cropLeft,
        'top': debugArtifacts.cropTop,
        'width': debugArtifacts.cropWidth,
        'height': debugArtifacts.cropHeight,
      },
      'document_config': documentConfig,
      'files': {
        'full_frame': fullFramePath,
        'model_input_224': modelInputPath,
      },
    };

    await File(metadataPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
    );

    final localFilePaths = [
      metadataPath,
      fullFramePath,
      modelInputPath,
    ];
    final downloadExport = await DebugExportChannel.exportFilesToDownloads(
      directoryName: 'quality_debug_exports/$runId/sample_$timestamp',
      sourcePaths: localFilePaths,
    );
    final finalDirectoryPath = downloadExport?.directoryPath.isNotEmpty == true
        ? downloadExport!.directoryPath
        : exportDirectory.path;

    return DocumentQualityDebugExportResult(
      directoryPath: finalDirectoryPath,
      metadataPath: metadataPath,
      fullFramePath: fullFramePath,
      modelInputPath: modelInputPath,
      shareableFilePaths: localFilePaths,
    );
  }
}

final documentQualityDebugExporterProvider =
    Provider<DocumentQualityDebugExporter>((ref) {
  return DocumentQualityDebugExporter();
});
