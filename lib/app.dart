import 'package:flutter/material.dart';

import 'core/features/kyc/presentation/screens/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/toast_utils.dart';
import 'helpers/navigation_helpers.dart';

class KycApp extends StatelessWidget {
  const KycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KYC Verification',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      navigatorKey: NavigationHelpers.navigationKey,
      scaffoldMessengerKey: ToastUtil.messengerKey,
      home: const KycHomeScreen(),
    );
  }
}
