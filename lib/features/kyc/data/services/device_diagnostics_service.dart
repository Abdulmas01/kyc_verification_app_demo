import 'dart:io';

import 'package:flutter/services.dart';

class DeviceDiagnosticsService {
  const DeviceDiagnosticsService();

  static const MethodChannel _channel = MethodChannel('kyc_device_diagnostics');

  Future<Map<String, dynamic>> collectSnapshot() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'collectSnapshot',
      );
      if (result != null && result.isNotEmpty) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {
      // Fall back to portable Dart-only metadata when the native channel
      // is unavailable.
    }

    return {
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'number_of_processors': Platform.numberOfProcessors,
      'path_separator': Platform.pathSeparator,
    };
  }
}
