import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ml/model_loader.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  if (kDebugMode) {
    final verificationApiKey = dotenv.env['KYC_VERIFICATION_API_KEY']?.trim();
    if (verificationApiKey == null || verificationApiKey.isEmpty) {
      logPrint(
        'KYC verification API key is missing. Add '
        '`KYC_VERIFICATION_API_KEY` to your local `.env` before running '
        'backend verification tests.',
      );
    }
  }
  await ModelLoader.init();
  runApp(const ProviderScope(child: KycApp()));
}
