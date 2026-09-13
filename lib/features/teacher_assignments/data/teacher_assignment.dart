import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// An actual teaching responsibility: this teacher currently teaches this
/// subject to this batch, in this class, in this academic session (Set
/// 22 spec). Deliberately separate from [TeacherProfile.subjectIds] (Set
/// 12), which is only the teacher's CAPABILITY - the subjects they are
/// configured to be able to teach, independent of any batch. A teacher
/// may hold any number of assignments across different sessions/classes/
/// batches/subjects; nothing here limits them to one of anything.
///
/// [assignmentId] is deterministic - [idFor] - so the same
/// teacher+session+batch+subject combination always maps to the same
/// document (the identity Set 22 section 6 asks to make duplication
/// "difficult to create" by construction, the same technique already
/// used for `attendance` (`batchId_dateKey`) and `teacherAttendance`
/// (`teacherUid_dateKey`)). [classId] is stored alongside [batchId]
/// (rather than only being derivable by looking the batch up) so a query
/// - and the admin list screen's class filter - never needs a join, the
/// same reasoning already applied to `attendance`/`tests`/`academicWork`;
/// `firestore.rules` cross-checks it against the batch's own `classId` at
/// write time (see `assignmentBatchIsConsistent`), so it can never
/// silently drift from the batch it names.
///
/// No teacher/class/batch/subject display name is snapshotted here -
/// unlike `TestDefinition.subject`/`AcademicWork.subject`, there is no
/// existing consumer that needs a plain display string yet (this set
/// builds the only two screens that read this collection), so every
/// display name is resolved live from the Set 9/10/12 master-data
/// providers, keeping this model to the "smallest appropriate" shape the
/// spec asks for.
///
/// [active]/[createdAt]/[updatedAt]/[createdBy]/[updatedBy] follow the
/// same deactivate-not-delete, audited-write convention as every other
/// operational record in this project (Batch, TeacherProfile, Student,
/// TestDefinition, ...). Deactivating an assignment never deletes it -
/// see [TeacherAssignmentController.setActive] - so a teacher's past
/// teaching responsibility stays historically visible even after they
/// stop teaching that batch/subject.
class TeacherAssignment implements FirestoreDocument {
  const TeacherAssignment({
    required this.assignmentId,
    required this.teacherId,
    required this.academicSessionId,
    required this.classId,
    required this.batchId,
    required this.subjectId,
    required this.active,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherAssignment.fromMap(String id, Map<String, dynamic> map) {
    return TeacherAssignment(
      assignmentId: id,
      teacherId: map['teacherId'] as String,
      academicSessionId: map['academicSessionId'] as String,
      classId: map['classId'] as String,
      batchId: map['batchId'] as String,
      subjectId: map['subjectId'] as String,
      active: map['active'] as bool,
      createdBy: map['createdBy'] as String,
      updatedBy: map['updatedBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// The deterministic document id for one teacher+session+batch+subject
  /// combination - see the class doc comment for why. A class isn't part
  /// of this id: a batch belongs to exactly one class (Set 10), so
  /// `batchId` alone already disambiguates it, exactly like
  /// `attendance`'s `batchId_dateKey` needs no separate session segment.
  static String idFor({
    required String teacherId,
    required String academicSessionId,
    required String batchId,
    required String subjectId,
  }) => '${teacherId}_${academicSessionId}_${batchId}_$subjectId';

  final String assignmentId;
  final String teacherId;
  final String academicSessionId;
  final String classId;
  final String batchId;
  final String subjectId;
  final bool active;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => assignmentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'batchId': batchId,
      'subjectId': subjectId,
      'active': active,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
