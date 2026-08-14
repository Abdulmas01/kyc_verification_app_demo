import 'package:flutter/services.dart';

class DebugShareChannel {
  static const MethodChannel _channel = MethodChannel('kyc_debug_share');

  static Future<void> shareText({
    required String subject,
    required String text,
  }) async {
    await _channel.invokeMethod<void>('shareText', {
      'subject': subject,
      'text': text,
    });
  }

  static Future<void> shareFiles({
    required String subject,
    required List<String> filePaths,
    String? text,
  }) async {
    await _channel.invokeMethod<void>('shareFiles', {
      'subject': subject,
      'text': text,
      'paths': filePaths,
    });
  }
}
