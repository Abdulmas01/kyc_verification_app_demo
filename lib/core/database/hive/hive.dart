import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:kyc_verification_app_demo/core/database/hive/hive_constants.dart';
import 'package:path_provider/path_provider.dart' as path;

class HiveBox {
  static final HiveBox _instance = HiveBox._();

  factory HiveBox() => _instance;

  HiveBox._();

  late Box<String?> deviceBox;

  Future<void> init() async {
    final Directory directory = await path.getApplicationDocumentsDirectory();
    Hive.init(directory.path);
    _registerAdaptors();
    final hiveEncryptionKey = await _encryptionKey;
    await _openBoxes(hiveEncryptionKey);
  }

  Future<void> clearAllData() async {
    await deviceBox.clear();
  }

  void _registerAdaptors() {
    Hive;
  }

  Future<Uint8List> get _encryptionKey async {
    const secureStorage = FlutterSecureStorage();
    final encryptionKey = await secureStorage.read(
      key: HiveConstants.encryptionKey,
    );

    if (encryptionKey == null) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: HiveConstants.encryptionKey,
        value: base64UrlEncode(key),
      );
    }

    final key = await secureStorage.read(key: HiveConstants.encryptionKey);
    return base64Url.decode(key!);
  }

  Future<void> _openBoxes(Uint8List hiveEncryptionKey) async {
    deviceBox = await Hive.openBox<String?>(
      HiveConstants.deviceBox,
      encryptionCipher: HiveAesCipher(hiveEncryptionKey),
    );
  }
}
