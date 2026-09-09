/// Canonical Firebase Storage top-level path prefixes.
///
/// Mirrors [FirestoreCollections] for Storage: a single source of truth
/// for where each asset type lives, matched by storage.rules. See
/// docs/database-architecture.md for details.
abstract final class StoragePaths {
  static const studentPhotos = 'student_photos';
  static const teacherPhotos = 'teacher_photos';
  static const gallery = 'gallery';
  static const banners = 'banners';
  static const advertisements = 'advertisements';
  static const instituteLogo = 'institute_logo';
  static const reportAssets = 'report_assets';
}
