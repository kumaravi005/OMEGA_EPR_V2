/// Named route paths for the app's navigation (go_router).
///
/// PUBLIC: [publicHome], [login] - reachable without being signed in.
/// PROTECTED: everything else - gated by [core/routing/app_router.dart]'s
/// redirect logic, which also enforces role (an account can only reach
/// its own role's area).
abstract final class AppRoutes {
  static const publicHome = '/';
  static const login = '/login';

  static const admin = '/admin';
  static const adminAccounts = '/admin/accounts';
  static const adminCreateAccount = '/admin/create-account';
  static const adminTeachers = '/admin/teachers';
  static const adminNewTeacher = '/admin/teachers/new';
  static const adminBatches = '/admin/batches';
  static const adminTeacherAssignments = '/admin/teacher-assignments';
  static const adminStudents = '/admin/students';
  static const adminNewStudent = '/admin/students/new';
  static const adminFeeDues = '/admin/fee-dues';
  static const adminAttendance = '/admin/attendance';
  static const adminMarkStudentAttendance = '/admin/attendance/students';
  static const adminMarkTeacherAttendance = '/admin/attendance/teachers';
  static const adminStudentAttendanceHistory =
      '/admin/attendance/students/history';
  static const adminTeacherAttendanceHistory =
      '/admin/attendance/teachers/history';
  static const adminAcademicWork = '/admin/homework-assignments';
  static const adminTests = '/admin/tests';
  static const adminResults = '/admin/results';
  static const adminTestResult = '/admin/results/test';
  static const adminCombinedResult = '/admin/results/combined';
  static const adminGallery = '/admin/gallery';
  static const adminBanners = '/admin/banners';
  static const adminUpcomingBatches = '/admin/upcoming-batches';
  static const adminAdvertisements = '/admin/advertisements';
  static const adminAnnouncements = '/admin/announcements';
  static const adminInstituteProfile = '/admin/institute-profile';
  static const adminEnquiries = '/admin/enquiries';
  static const adminCallbackRequests = '/admin/callback-requests';
  static const adminNotifications = '/admin/notifications';
  static const adminNotices = '/admin/notices';
  static const adminReports = '/admin/reports';
  static const adminStudentExport = '/admin/reports/students';
  static const adminFeeDuesExport = '/admin/reports/fee-dues';
  static const adminTestResultExport = '/admin/reports/test-results';
  static const adminPaymentReport = '/admin/reports/payments';
  static const adminReportTemplates = '/admin/report-templates';
  static const adminReportTemplateNew = '/admin/report-templates/new';
  static const adminConfiguration = '/admin/configuration';
  static const adminAcademicSessions = '/admin/configuration/sessions';
  static const adminClasses = '/admin/configuration/classes';
  static const adminBoards = '/admin/configuration/boards';
  static const adminSubjects = '/admin/configuration/subjects';

  static const teacher = '/teacher';
  static const teacherAssignments = '/teacher/assignments';
  static const teacherMarkAttendance = '/teacher/attendance/mark';
  static const teacherAttendance = '/teacher/attendance';
  static const teacherAcademicWork = '/teacher/homework-assignments';
  static const teacherTests = '/teacher/tests';
  static const teacherNotifications = '/teacher/notifications';
  static const teacherNotices = '/teacher/notices';

  static const student = '/student';
  static const studentAttendance = '/student/attendance';
  static const studentAcademicWork = '/student/homework-assignments';
  static const studentResults = '/student/results';
  static const studentFees = '/student/fees';
  static const studentNotifications = '/student/notifications';
  static const studentNotices = '/student/notices';
}
