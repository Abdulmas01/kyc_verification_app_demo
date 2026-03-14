class HiveConstants {
  HiveConstants._();

  static const encryptionKey = "hive_key";
  static const authKey = "token";
  static const authBox = "authBox";
  static const userKey = "user";
  static const userBox = "userBox";
  static const deviceBox = "deviceBox";
  static const deviceIdKey = "deviceId";
  static const deviceUserIdKey = "deviceUserId";
  static const deviceUserEmailKey = "deviceUserEmail";
  static const String settingsBox = "settings_box";
  static const String settingsKey = "app_settings";
}

class HiveTypeIds {
  HiveTypeIds._();

  static const int userModel = 1;
  static const int authSession = 2;
  static const int appSettings = 3;
  static const int subscriptionPlanEnum = 5;
  static const int subscriptionSummaryModel = 6;
  static const int chatModel = 7;
  static const int fileMataDataModel = 35;
  static const int chatSession = 8;
  static const int chatMessageWithUser = 20;

  static const int identityKeyPairModel = 10;
  static const int signedPreKeyModel = 11;
  static const int oneTimePreKeyModel = 12;

  static const int userKeysModel = 13;
  static const int notificationSettingsModel = 19;
  static const int loginResponse = 21;
  static const int authProviderEnum = 22;
  static const int accountTypeEnum = 23;
}
