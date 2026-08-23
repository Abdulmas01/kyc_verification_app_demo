import 'dart:io';

import 'package:flutter/services.dart';

class DebugExportChannelResult {
  const DebugExportChannelResult({
    required this.directoryPath,
    required this.exportedFilePaths,
  });

  final String directoryPath;
  final List<String> exportedFilePaths;
}

class DebugExportChannel {
  static const MethodChannel _channel = MethodChannel('kyc_debug_export');

  static Future<DebugExportChannelResult?> exportFilesToDownloads({
    required String directoryName,
    required List<String> sourcePaths,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }

    final response = await _channel
        .invokeMapMethod<String, dynamic>('exportFilesToDownloads', {
      'directoryName': directoryName,
      'paths': sourcePaths,
    });
    if (response == null) {
      return null;
    }

    final exported =
        (response['exportedFilePaths'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);

    return DebugExportChannelResult(
      directoryPath: response['directoryPath']?.toString() ?? '',
      exportedFilePaths: exported,
    );
  }
}
