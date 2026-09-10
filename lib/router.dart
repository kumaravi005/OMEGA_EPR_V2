import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/routing/app_routes.dart';
import 'core/services/auth_service.dart';
import 'features/admin/presentation/admin_accounts_screen.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/admin/presentation/create_account_screen.dart';
import 'features/assignments/presentation/assignment_list_screen.dart';
import 'features/assignments/presentation/student_assignments_screen.dart';
import 'features/attendance/presentation/mark_student_attendance_screen.dart';
import 'features/attendance/presentation/mark_teacher_attendance_screen.dart';
import 'features/attendance/presentation/student_attendance_history_screen.dart';
import 'features/attendance/presentation/teacher_attendance_history_screen.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/application/device_id_service.dart';
import 'features/auth/data/user_account.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/batches/presentation/batch_list_screen.dart';
import 'features/enquiries/presentation/callback_requests_screen.dart';
import 'features/enquiries/presentation/enquiries_screen.dart';
import 'features/homework/presentation/homework_list_screen.dart';
import 'features/homework/presentation/student_homework_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/public/presentation/admin/advertisements_screen.dart';
import 'features/public/presentation/admin/announcements_screen.dart';
import 'features/public/presentation/admin/banners_screen.dart';
import 'features/public/presentation/admin/gallery_screen.dart';
import 'features/public/presentation/admin/institute_profile_screen.dart';
import 'features/public/presentation/admin/upcoming_batches_screen.dart';
import 'features/public/presentation/public_home_screen.dart';
import 'features/report_templates/presentation/report_layout_templates_screen.dart';
import 'features/report_templates/presentation/report_template_designer_screen.dart';
import 'features/reports/presentation/fee_dues_export_screen.dart';
import 'features/reports/presentation/reports_hub_screen.dart';
import 'features/reports/presentation/student_export_screen.dart';
import 'features/reports/presentation/test_result_export_screen.dart';
import 'features/student/presentation/fee_dues_screen.dart';
import 'features/student/presentation/student_fee_screen.dart';
import 'features/student/presentation/student_form_screen.dart';
import 'features/student/presentation/student_home_screen.dart';
import 'features/student/presentation/student_list_screen.dart';
import 'features/student/presentation/student_profile_screen.dart';
import 'features/teacher/presentation/teacher_form_screen.dart';
import 'features/teacher/presentation/teacher_home_screen.dart';
import 'features/teacher/presentation/teacher_list_screen.dart';
import 'features/tests/presentation/enter_marks_screen.dart';
import 'features/tests/presentation/student_results_screen.dart';
import 'features/tests/presentation/test_list_screen.dart';

/// The app's route table and role-based/session-based redirect logic.
///
/// This is the one place allowed to import across every feature - it's
/// the composition root, not `core/` (which stays feature-agnostic) and
/// not any single `features/*` module.
const _publicPaths = {AppRoutes.publicHome, AppRoutes.login};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier();
  ref.listen<AsyncValue<Object?>>(currentUserAccountProvider, (previous, next) => refresh.notify());
  // deviceIdProvider depends on SharedPreferences loading asynchronously;
  // re-run redirect once it resolves so a restored session isn't stuck on
  // the public page if this fires before that.
  ref.listen<AsyncValue<Object?>>(sharedPreferencesProvider, (previous, next) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.publicHome,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.publicHome, builder: (context, state) => const PublicHomeScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),

      GoRoute(path: AppRoutes.admin, builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: AppRoutes.adminAccounts, builder: (context, state) => const AdminAccountsScreen()),
      GoRoute(path: AppRoutes.adminCreateAccount, builder: (context, state) => const CreateAccountScreen()),

      GoRoute(path: AppRoutes.adminTeachers, builder: (context, state) => const TeacherListScreen()),
      GoRoute(path: AppRoutes.adminNewTeacher, builder: (context, state) => const TeacherFormScreen()),
      GoRoute(
        path: '${AppRoutes.adminTeachers}/:uid/edit',
        builder: (context, state) => TeacherFormScreen(teacherUid: state.pathParameters['uid']),
      ),

      GoRoute(path: AppRoutes.adminBatches, builder: (context, state) => const BatchListScreen()),

      GoRoute(path: AppRoutes.adminStudents, builder: (context, state) => const StudentListScreen()),
      GoRoute(path: AppRoutes.adminNewStudent, builder: (context, state) => const StudentFormScreen()),
      GoRoute(
        path: '${AppRoutes.adminStudents}/:uid/edit',
        builder: (context, state) => StudentFormScreen(studentUid: state.pathParameters['uid']),
      ),
      GoRoute(
        path: '${AppRoutes.adminStudents}/:uid',
        builder: (context, state) => StudentProfileScreen(studentUid: state.pathParameters['uid']!),
      ),

      GoRoute(path: AppRoutes.adminFeeDues, builder: (context, state) => const FeeDuesScreen()),

      GoRoute(
        path: AppRoutes.adminMarkStudentAttendance,
        builder: (context, state) => const MarkStudentAttendanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminMarkTeacherAttendance,
        builder: (context, state) => const MarkTeacherAttendanceScreen(),
      ),

      GoRoute(
        path: AppRoutes.adminTests,
        builder: (context, state) => const TestListScreen(basePath: AppRoutes.adminTests),
      ),
      GoRoute(
        path: '${AppRoutes.adminTests}/:testId',
        builder: (context, state) => EnterMarksScreen(testId: state.pathParameters['testId']!),
      ),

      GoRoute(path: AppRoutes.adminGallery, builder: (context, state) => const GalleryScreen()),
      GoRoute(path: AppRoutes.adminBanners, builder: (context, state) => const BannersScreen()),
      GoRoute(path: AppRoutes.adminUpcomingBatches, builder: (context, state) => const UpcomingBatchesScreen()),
      GoRoute(path: AppRoutes.adminAdvertisements, builder: (context, state) => const AdvertisementsScreen()),
      GoRoute(path: AppRoutes.adminAnnouncements, builder: (context, state) => const AnnouncementsScreen()),
      GoRoute(path: AppRoutes.adminInstituteProfile, builder: (context, state) => const InstituteProfileScreen()),
      GoRoute(path: AppRoutes.adminEnquiries, builder: (context, state) => const EnquiriesScreen()),
      GoRoute(path: AppRoutes.adminCallbackRequests, builder: (context, state) => const CallbackRequestsScreen()),
      GoRoute(path: AppRoutes.adminNotifications, builder: (context, state) => const NotificationsScreen()),

      GoRoute(path: AppRoutes.adminReports, builder: (context, state) => const ReportsHubScreen()),
      GoRoute(path: AppRoutes.adminStudentExport, builder: (context, state) => const StudentExportScreen()),
      GoRoute(path: AppRoutes.adminFeeDuesExport, builder: (context, state) => const FeeDuesExportScreen()),
      GoRoute(path: AppRoutes.adminTestResultExport, builder: (context, state) => const TestResultExportScreen()),

      GoRoute(path: AppRoutes.adminReportTemplates, builder: (context, state) => const ReportLayoutTemplatesScreen()),
      GoRoute(path: AppRoutes.adminReportTemplateNew, builder: (context, state) => const ReportTemplateDesignerScreen()),
      GoRoute(
        path: '${AppRoutes.adminReportTemplates}/:templateId/edit',
        builder: (context, state) => ReportTemplateDesignerScreen(templateId: state.pathParameters['templateId']),
      ),

      GoRoute(path: AppRoutes.teacher, builder: (context, state) => const TeacherHomeScreen()),
      GoRoute(
        path: AppRoutes.teacherAttendance,
        builder: (context, state) => const TeacherAttendanceHistoryScreen(),
      ),
      GoRoute(path: AppRoutes.teacherHomework, builder: (context, state) => const HomeworkListScreen()),
      GoRoute(path: AppRoutes.teacherAssignments, builder: (context, state) => const AssignmentListScreen()),
      GoRoute(
        path: AppRoutes.teacherTests,
        builder: (context, state) => const TestListScreen(basePath: AppRoutes.teacherTests),
      ),
      GoRoute(
        path: '${AppRoutes.teacherTests}/:testId',
        builder: (context, state) => EnterMarksScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(path: AppRoutes.teacherNotifications, builder: (context, state) => const NotificationsScreen()),

      GoRoute(path: AppRoutes.student, builder: (context, state) => const StudentHomeScreen()),
      GoRoute(
        path: AppRoutes.studentAttendance,
        builder: (context, state) => const StudentAttendanceHistoryScreen(),
      ),
      GoRoute(path: AppRoutes.studentHomework, builder: (context, state) => const StudentHomeworkScreen()),
      GoRoute(path: AppRoutes.studentAssignments, builder: (context, state) => const StudentAssignmentsScreen()),
      GoRoute(path: AppRoutes.studentResults, builder: (context, state) => const StudentResultsScreen()),
      GoRoute(path: AppRoutes.studentFees, builder: (context, state) => const StudentFeeScreen()),
      GoRoute(path: AppRoutes.studentNotifications, builder: (context, state) => const NotificationsScreen()),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final path = state.matchedLocation;
  final isPublicPath = _publicPaths.contains(path);

  final authAsync = ref.read(authStateChangesProvider);
  if (authAsync.isLoading) return null;

  final firebaseUser = authAsync.valueOrNull;
  if (firebaseUser == null) {
    return isPublicPath ? null : AppRoutes.login;
  }

  final accountAsync = ref.read(currentUserAccountProvider);
  if (accountAsync.isLoading) return null;

  final account = accountAsync.valueOrNull;
  // A missing/inactive account or a session claimed by another device is
  // handled by the app-level listener, which forces a sign-out with an
  // explanation - don't bounce the UI mid-way through that.
  if (account == null || !account.active) return null;

  final deviceId = ref.read(deviceIdProvider);
  if (deviceId == null || account.session?.deviceId != deviceId) return null;

  final home = _homeFor(account.role);
  if (isPublicPath) return home;
  if (!path.startsWith(home)) return home;
  return null;
}

String _homeFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppRoutes.admin;
    case UserRole.teacher:
      return AppRoutes.teacher;
    case UserRole.student:
      return AppRoutes.student;
  }
}

/// A [Listenable] go_router can watch, notified by [ref.listen] whenever
/// auth/session state changes, so it re-runs [redirect].
class _GoRouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
