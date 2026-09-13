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

  // Added in Set 7 - distinct from `reportTemplates` (Set 6's saved
  // export column/filter configs): this is the visual A4 header/footer
  // letterhead template.
  static const reportLayoutTemplates = 'reportLayoutTemplates';

  // Added in Set 9 - academic master data. `academicSessions` and
  // `subjects` were already declared above (from the original Set 1
  // plan); `classes` and `boards` were not anticipated then.
  static const classes = 'classes';
  static const boards = 'boards';

  // Added in Set 11 - a tiny collection of atomic sequence counters (see
  // SequenceService), currently only `counters/students` for admission
  // numbers. Not a general-purpose settings/meta collection.
  static const counters = 'counters';

  // Added in Set 16 - replaces the separate `homework`/`assignments`
  // collections from Set 4 (their string constants above were removed
  // along with the collections themselves - see docs/database-
  // architecture.md's "Homework and assignments, unified (Set 16)").
  // One reusable model with a `type` field, instead of two duplicated
  // structures.
  static const academicWork = 'academicWork';

  // Added in Set 17 - admin-authored, targeted, published/closed notices
  // (Notices management). Deliberately NOT named `notifications`: that
  // name is already taken by the Set 4/5 auto-generated event trail
  // (`NotificationEvent`/`recordNotificationEvent`), a narrower, read-only
  // feed with no admin authoring, targeting, or read state - a distinct
  // feature this set does not touch (see docs/database-architecture.md's
  // "Notices (Set 17) vs the Set 4/5 notification event log"). Per-user
  // read state lives at `users/{uid}/noticeReadStates/{noticeId}`, not a
  // top-level collection.
  static const notices = 'notices';
}
