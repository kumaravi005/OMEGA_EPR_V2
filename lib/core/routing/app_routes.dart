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
  static const adminStudents = '/admin/students';
  static const adminNewStudent = '/admin/students/new';
  static const adminFeeDues = '/admin/fee-dues';

  static const teacher = '/teacher';

  static const student = '/student';
}
