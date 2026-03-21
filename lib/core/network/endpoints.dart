class Endpoints {
  Endpoints._();

//   static const String baseUrl = "http://192.168.1.180:8080";
  static const String baseUrl = "https://django-balewite-backend.onrender.com";
  static const String apiVersion = "api/v1";
  static const String apiBaseUrl = "$baseUrl/$apiVersion";

  // auth
  static const String authFeature = "auth";

  static const String loginPath = "$authFeature/login";
  static const String registerPath = "$authFeature/register";

  static String login = "$apiBaseUrl/$loginPath";
  static String register = "$apiBaseUrl/$registerPath";

  // notifications
  static const String notificationsListPath = "$apiBaseUrl/notifications/list";

  // fcm
  static const String updateFcmTokenPath = "$apiBaseUrl/update-fcm-token";

  // account
  static const String accountUpdatePath = "$apiBaseUrl/account/update";
  static const String accountChangePasswordPath =
      "$apiBaseUrl/account/changePassword";
  static const String accountPrivacyPath = "$apiBaseUrl/account/privacy";
  // KYC verification
  static const String verifyPath = "$apiBaseUrl/verify";
  static const String verifyStart = "$verifyPath/start/";
  static const String verifyUpload = "$verifyPath/upload/";
  static String verifyResult(String sessionId) => "$verifyPath/$sessionId/";
}
