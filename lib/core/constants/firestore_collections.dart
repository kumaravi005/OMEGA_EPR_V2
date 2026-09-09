/// Canonical Firestore collection names.
///
/// Centralised so every repository/query — now and in future phases —
/// references the same string constant instead of a literal, avoiding
/// typos and making renames a one-line change. Declaring a name here does
/// not create the collection; Firestore collections are created lazily on
/// first write. See docs/database-architecture.md for the planned shape
/// of each collection.
abstract final class FirestoreCollections {
  static const institutes = 'institutes';
  static const academicSessions = 'academicSessions';
  static const batches = 'batches';
  static const subjects = 'subjects';
  static const teachers = 'teachers';
  static const students = 'students';
  static const users = 'users';
  static const enquiries = 'enquiries';
  static const attendance = 'attendance';
  static const teacherAttendance = 'teacherAttendance';
  static const fees = 'fees';
  static const payments = 'payments';
  static const homework = 'homework';
  static const assignments = 'assignments';
  static const tests = 'tests';
  static const testResults = 'testResults';
  static const notifications = 'notifications';
  static const gallery = 'gallery';
  static const advertisements = 'advertisements';
  static const announcements = 'announcements';
  static const reportTemplates = 'reportTemplates';
  static const auditLogs = 'auditLogs';

  // Added in Set 5 - not anticipated by the original Set 1 list.
  static const banners = 'banners';
  static const upcomingBatches = 'upcomingBatches';
  static const callbackRequests = 'callbackRequests';
}
