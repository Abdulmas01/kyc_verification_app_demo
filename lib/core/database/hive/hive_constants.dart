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

  static const String walletBox = "walletBox";
  static const String walletKey = "wallet";
  static const String hideBalanceKey = "hideBalance";
  static const String subscriptionBox = "subscriptionBox";
  static const String subscriptionSummaryKey = "subscriptionSummary";
  static const String chatMessagesBox = "chat_messages_box";

  static const String signalIdentityBox = "signal_identity_box";
  static const String signalPreKeyBox = "signal_prekey_box";
  static const String signalSignedPreKeyBox = "signal_signed_prekey_box";
  static const String signalSessionBox = "signal_session_box";
  static const String signalMetaBox = "signal_meta_box";
  static const String signalUserKeysBox = "signal_user_keys_box";

  static const String identityKeyPairKey = "identity_key_pair";
  static const String registrationIdKey = "registration_id";
  // TODO : comapare with this chatMessagesBox to make sure everything is working
  // and we dont have dublicate stuff
  static const String messagesBoxName = 'chat_messages';
  static const String sessionsBoxName = 'chat_sessions';
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
