import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ml/model_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ModelLoader.init();
  runApp(const ProviderScope(child: KycApp()));
}
