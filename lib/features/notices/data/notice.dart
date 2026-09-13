import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A small, controlled, extensible type/category vocabulary (Set 17
/// spec section 6) - adding a new value later is a one-line change,
/// mirroring `TestType`'s `other`/`otherTestTypeLabel` pattern exactly
/// (see [Notice.otherTypeLabel]).
enum NoticeType {
  general,
  academic,
  examTest,
  homework,
  attendance,
  fee,
  event,
  important,
  other;

  static NoticeType fromValue(String value) {
    return NoticeType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw ArgumentError('Unknown notice type: $value'),
    );
  }

  String get label => switch (this) {
    NoticeType.general => 'General',
    NoticeType.academic => 'Academic',
    NoticeType.examTest => 'Exam/Test',
    NoticeType.homework => 'Homework',
    NoticeType.attendance => 'Attendance',
    NoticeType.fee => 'Fee',
    NoticeType.event => 'Event',
    NoticeType.important => 'Important',
    NoticeType.other => 'Other',
  };
}

/// Who a notice is written for, as the admin describes it (Set 17
/// section 3). [NoticeAudience.students] and [NoticeAudience.parents]
/// are delivered identically - this project has no separate parent
/// login (a parent uses the student's own account, see
/// docs/database-architecture.md's "Parents share the student login") -
/// [audience] only changes how the notice is LABELLED, never who can
/// read it; targeting/security is entirely driven by [Notice.targetKey]
/// (see `computeTargetKey`).
enum NoticeAudience {
  all,
  students,
  parents,
  teachers;

  static NoticeAudience fromValue(String value) {
    return NoticeAudience.values.firstWhere(
      (audience) => audience.name == value,
      orElse: () => throw ArgumentError('Unknown notice audience: $value'),
    );
  }

  String get label => switch (this) {
    NoticeAudience.all => 'Everyone',
    NoticeAudience.students => 'Students',
    NoticeAudience.parents => 'Parents',
    NoticeAudience.teachers => 'Teachers',
  };
}

/// How far a students/parents-audience notice reaches (Set 17 section
/// 4). Meaningless for [NoticeAudience.all]/[NoticeAudience.teachers],
/// which are always [institute]-wide - see `scopeIsConsistent` in
/// firestore.rules.
enum NoticeScope {
  institute,
  byClass,
  byBatch;

  static NoticeScope fromValue(String value) {
    return NoticeScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => throw ArgumentError('Unknown notice scope: $value'),
    );
  }

  String get label => switch (this) {
    NoticeScope.institute => 'Everyone in this audience',
    NoticeScope.byClass => 'One class',
    NoticeScope.byBatch => 'One batch',
  };
}

/// A one-way lifecycle (Set 17 section 8): Draft -> Published -> Closed.
/// Unlike Set 16's freely-reversible `AcademicWorkStatus`, the Set 17
/// spec only ever lists forward admin actions ("edit draft / publish
/// draft / close published notification" - no "reopen"/"unpublish"), so
/// this mirrors Set 14's one-way `resultPublished` instead - see
/// `noticeUpdateIsValid` in firestore.rules.
enum NoticeStatus {
  draft,
  published,
  closed;

  static NoticeStatus fromValue(String value) {
    return NoticeStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown notice status: $value'),
    );
  }

  String get label => switch (this) {
    NoticeStatus.draft => 'Draft',
    NoticeStatus.published => 'Published',
    NoticeStatus.closed => 'Closed',
  };
}

/// An admin-authored notice, shared by every eligible recipient - never
/// one document per student/parent/teacher (Set 17 section 26).
///
/// [targetKey] is the single field the visibility rule and every
/// recipient query key off (see `computeTargetKey`): it collapses
/// [audience]/[scope]/[classId]/[batchId] into one string so a
/// recipient's feed is a single `whereIn` query (the same "combine one
/// equality-ish query, merge nothing extra" shape already proven safe
/// for `academicWork` - see docs/database-architecture.md's "Firestore
/// query-shape requirement, once more"). [academicSessionId] is a
/// display-only snapshot (current class/batch membership already
/// determines visibility - see "Current vs historical context" in the
/// docs), never part of targeting itself.
///
/// [isPublic] (Set 18) is an entirely separate, admin-only-settable
/// switch that additionally exposes an already-[NoticeStatus.published]
/// notice to unauthenticated public visitors - it does not replace or
/// interact with [targetKey]/[audience]/[scope], which still govern
/// visibility to signed-in admin/teacher/student/parent accounts exactly
/// as before. See `publicNoticesProvider` and docs/database-
/// architecture.md's "Public notices (Set 18)".
class Notice implements FirestoreDocument {
  const Notice({
    required this.noticeId,
    required this.title,
    required this.message,
    required this.type,
    this.otherTypeLabel,
    required this.audience,
    required this.scope,
    this.academicSessionId,
    this.classId,
    this.batchId,
    required this.targetKey,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.expiresAt,
    this.isPublic = false,
  });

  factory Notice.fromMap(String id, Map<String, dynamic> map) {
    return Notice(
      noticeId: id,
      title: map['title'] as String,
      message: map['message'] as String,
      type: NoticeType.fromValue(map['type'] as String),
      otherTypeLabel: map['otherTypeLabel'] as String?,
      audience: NoticeAudience.fromValue(map['audience'] as String),
      scope: NoticeScope.fromValue(map['scope'] as String),
      // Defaults to false on a pre-Set-18 notice document, which predates
      // this field entirely - never publicly visible until an admin
      // explicitly opts it in (see `setPublicVisibility`).
      isPublic: map['isPublic'] as bool? ?? false,
      academicSessionId: map['academicSessionId'] as String?,
      classId: map['classId'] as String?,
      batchId: map['batchId'] as String?,
      targetKey: map['targetKey'] as String,
      status: NoticeStatus.fromValue(map['status'] as String),
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  final String noticeId;
  final String title;
  final String message;
  final NoticeType type;

  /// Only set (and only meaningful) when [type] is [NoticeType.other].
  final String? otherTypeLabel;
  final NoticeAudience audience;
  final NoticeScope scope;

  /// Display-only snapshot of the currently-active session at creation
  /// time - `null` for [NoticeScope.institute]. Never used for
  /// targeting (see class doc comment).
  final String? academicSessionId;

  /// Set for [NoticeScope.byClass] and [NoticeScope.byBatch].
  final String? classId;

  /// Set only for [NoticeScope.byBatch].
  final String? batchId;

  /// Derived from [audience]/[scope]/[classId]/[batchId] - see
  /// [computeTargetKey]. The one field firestore.rules and every
  /// recipient query actually depend on.
  final String targetKey;
  final NoticeStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set once, the moment this notice first became [NoticeStatus.published]
  /// (including immediately, if created already published) - `null` while
  /// still a draft.
  final DateTime? publishedAt;

  /// Optional (Set 17 section 21). Purely a display/"active list" concern,
  /// calculated via [isExpired] - never a stored boolean, and never a
  /// Firestore-rules dependency (an expired-but-published notice was
  /// still legitimately visible; expiry just stops it being "active").
  final DateTime? expiresAt;

  /// Admin-only visibility switch to the unauthenticated public site
  /// (Set 18) - see class doc comment. Defaults to `false`; never implied
  /// by [status] or [audience].
  final bool isPublic;

  bool isExpired(DateTime now) => expiresAt != null && now.isAfter(expiresAt!);

  @override
  String get id => noticeId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'otherTypeLabel': otherTypeLabel,
      'audience': audience.name,
      'scope': scope.name,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'batchId': batchId,
      'targetKey': targetKey,
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'publishedAt': publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'isPublic': isPublic,
    };
  }

  /// The single source of truth for "who can see this notice", computed
  /// identically here and in firestore.rules' `expectedTargetKey` (kept
  /// in sync by hand - there is no shared-code path between Dart and
  /// Rules in this project). [NoticeAudience.students] and
  /// [NoticeAudience.parents] deliberately produce the SAME key at the
  /// same scope (both reach the one shared student/parent login) - see
  /// the class doc comment on [NoticeAudience].
  static String computeTargetKey({
    required NoticeAudience audience,
    required NoticeScope scope,
    String? classId,
    String? batchId,
  }) {
    if (audience == NoticeAudience.all) return 'all';
    if (audience == NoticeAudience.teachers) return 'teachers';
    switch (scope) {
      case NoticeScope.institute:
        return 'students';
      case NoticeScope.byClass:
        return 'students:class:$classId';
      case NoticeScope.byBatch:
        return 'students:batch:$batchId';
    }
  }
}
