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

  // courses
  static const String coursesPath = "$apiBaseUrl/courses";
  static const String coursesLecturersPath = "$apiBaseUrl/courses/lecturers";
  static String courses = "$apiBaseUrl/$coursesPath";

  // school links
  static const String schoolLinksPath = "$apiBaseUrl/school-links";
  static const String schoolLinkPath = "$apiBaseUrl/school-link";
  static String schoolLinks = "$apiBaseUrl/$schoolLinksPath";

  // schools
  static const String schoolsPath = "$apiBaseUrl/school";
  static String schools = "$apiBaseUrl/$schoolsPath";

  // department
  static const String departmentFeature = "$apiBaseUrl/department";
  static const String departmentBatchPath = "$departmentFeature/batch";
  static const String departmentAnnouncementPath =
      "$departmentFeature/announcement";

  static String departments = "$apiBaseUrl/$departmentFeature";

  // quizzes
  static const String quizzesPath = "$apiBaseUrl/quizzes";
  static String quizzes = "$apiBaseUrl/$quizzesPath";

  static const String lostItemsPath = "$apiBaseUrl/lost-items";
  static String lostItems = "$apiBaseUrl/$lostItemsPath";

  // timetable / batch
  static const String timetablePath = "$apiBaseUrl/timetable";
  static const String batchDepartmentPath = "$apiBaseUrl/batch/department";

  // announcements
  static const String announcementPath = "$apiBaseUrl/announcement";

  // reports & guides
  static const String reportPath = "$apiBaseUrl/report";
  static const String schoolRulesPath = "$apiBaseUrl/school-rules";
  static const String technicalReportFormatPath =
      "$apiBaseUrl/technicalReport/format";
  static const String technicalReportSamplePath =
      "$apiBaseUrl/technicalReport/sample";
  static const String itDefenceSamplePath = "$apiBaseUrl/itDefenceSample";
  static const String fresherGuidePath = "$apiBaseUrl/guide/fresher-guide";
  static const String projectTopicPath = "$apiBaseUrl/project/topic";
  static const String projectSamplePath = "$apiBaseUrl/project/sample";

  // downloads & materials
  static const String materialDownloadPath = "$apiBaseUrl/material-download";
  static const String materialDownloadSearchPath =
      "$apiBaseUrl/material-download/search";

  // notifications
  static const String notificationsListPath = "$apiBaseUrl/notifications/list";

  // fcm
  static const String updateFcmTokenPath = "$apiBaseUrl/update-fcm-token";

  // CBT
  static const String cbtPath = "$apiBaseUrl/cbt";
  static const String cbtCoursePath = "$apiBaseUrl/cbt/course";
  static const String cbtCourseYearPath = "$apiBaseUrl/cbt/course/year";

  // locations
  static const String schoolLocationPath = "$apiBaseUrl/school-location";
  static const String schoolVenuePath = "$apiBaseUrl/school-venue";

  // events
  static const String eventPath = "$apiBaseUrl/event";

  // account
  static const String accountUpdatePath = "$apiBaseUrl/account/update";
  static const String accountChangePasswordPath =
      "$apiBaseUrl/account/changePassword";
  static const String accountPrivacyPath = "$apiBaseUrl/account/privacy";

  // forgot password
  static const String forgotPasswordPath = "$apiBaseUrl/api/forgot-password";
  static const String forgotPasswordResetPath =
      "$apiBaseUrl/forgot-password/reset";
  static const String forgotPasswordVerifyPasswordPath =
      "$apiBaseUrl/api/forgotPassword/verifypassword";
  static const String forgotPasswordQuestionPath = "$apiBaseUrl/forgotPassword";
  static const String forgotPasswordQuestionCheckPath =
      "$apiBaseUrl/forgotPassword/check";
}
