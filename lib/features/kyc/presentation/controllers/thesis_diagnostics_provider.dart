import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThesisDiagnosticsConfig {
  const ThesisDiagnosticsConfig({
    required this.enabled,
    required this.autoExportReports,
    required this.captureDocumentQualitySamples,
    required this.showDebugUi,
    this.captureLivenessSamples = false,
    this.captureFaceMatchSamples = false,
    this.verboseLogs = false,
  });

  final bool enabled;
  final bool autoExportReports;
  final bool captureDocumentQualitySamples;
  final bool showDebugUi;
  final bool captureLivenessSamples;
  final bool captureFaceMatchSamples;
  final bool verboseLogs;
}

final thesisDiagnosticsProvider = Provider<ThesisDiagnosticsConfig>((ref) {
  return const ThesisDiagnosticsConfig(
    enabled: kDebugMode,
    autoExportReports: kDebugMode,
    captureDocumentQualitySamples: kDebugMode,
    showDebugUi: kDebugMode,
    captureLivenessSamples: false,
    captureFaceMatchSamples: false,
    verboseLogs: kDebugMode,
  );
});
