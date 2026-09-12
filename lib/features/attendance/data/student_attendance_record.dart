import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum AttendanceStatus {
  present,
  absent;

  static AttendanceStatus fromValue(String value) {
    return AttendanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown attendance status: $value'),
    );
  }

  String get label => this == AttendanceStatus.present ? 'Present' : 'Absent';
}

/// One common attendance record per batch/date, covering every student in
/// that batch - never split by subject (see docs/database-architecture.md).
/// The document id is deterministic (`<batchId>_<dateKey>`), so marking
/// the same batch/date twice updates the same record instead of creating
/// a duplicate. Since a batch belongs to exactly one academic session
/// (Set 10), `<batchId>_<dateKey>` already uniquely identifies
/// session+batch+date - no session segment is needed in the id itself.
///
/// [academicSessionId]/[classId] are a **snapshot** of the batch's own
/// session/class at the moment attendance was marked (Set 13) - not a
/// live join - so a later edit to the batch's own session/class
/// assignment (rare, but technically possible) never retroactively
/// rewrites which session/class a past attendance record is reported
/// under. Both are `''` on a record created before Set 13.
class StudentAttendanceRecord implements FirestoreDocument {
  const StudentAttendanceRecord({
    required this.recordId,
    required this.batchId,
    required this.dateKey,
    required this.date,
    required this.academicSessionId,
    required this.classId,
    required this.records,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentAttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawRecords = (map['records'] as Map<String, dynamic>? ?? const {});
    // Pre-Set-13 documents stored a single `markedBy` field for both who
    // created and who last touched the record - fall back to it so an
    // old record still reports a sensible (if less precise) createdBy/
    // updatedBy rather than an empty string.
    final legacyMarkedBy = map['markedBy'] as String?;
    return StudentAttendanceRecord(
      recordId: id,
      batchId: map['batchId'] as String,
      dateKey: map['dateKey'] as String,
      date: (map['date'] as Timestamp).toDate(),
      academicSessionId: map['academicSessionId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      records: rawRecords.map(
        (uid, status) =>
            MapEntry(uid, AttendanceStatus.fromValue(status as String)),
      ),
      createdBy: map['createdBy'] as String? ?? legacyMarkedBy ?? '',
      updatedBy: map['updatedBy'] as String? ?? legacyMarkedBy ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String recordId;
  final String batchId;
  final String dateKey;
  final DateTime date;
  final String academicSessionId;
  final String classId;

  /// studentUid -> status, for every student marked on this date.
  final Map<String, AttendanceStatus> records;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get presentCount =>
      records.values.where((s) => s == AttendanceStatus.present).length;

  int get absentCount =>
      records.values.where((s) => s == AttendanceStatus.absent).length;

  @override
  String get id => recordId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'dateKey': dateKey,
      'date': Timestamp.fromDate(date),
      'academicSessionId': academicSessionId,
      'classId': classId,
      'records': records.map((uid, status) => MapEntry(uid, status.name)),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
