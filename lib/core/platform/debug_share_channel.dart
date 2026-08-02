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
}
