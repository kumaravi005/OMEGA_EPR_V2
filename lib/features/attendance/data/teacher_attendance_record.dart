import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import 'student_attendance_record.dart' show AttendanceStatus;

/// One attendance record per teacher per date. Document id is
/// deterministic (`<teacherUid>_<dateKey>`) so marking the same
/// teacher/date twice updates the same record rather than duplicating it.
class TeacherAttendanceRecord implements FirestoreDocument {
  const TeacherAttendanceRecord({
    required this.recordId,
    required this.teacherUid,
    required this.dateKey,
    required this.date,
    required this.status,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherAttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    // Pre-Set-13 documents stored a single `markedBy` field - see
    // StudentAttendanceRecord.fromMap for the identical fallback.
    final legacyMarkedBy = map['markedBy'] as String?;
    return TeacherAttendanceRecord(
      recordId: id,
      teacherUid: map['teacherUid'] as String,
      dateKey: map['dateKey'] as String,
      date: (map['date'] as Timestamp).toDate(),
      status: AttendanceStatus.fromValue(map['status'] as String),
      createdBy: map['createdBy'] as String? ?? legacyMarkedBy ?? '',
      updatedBy: map['updatedBy'] as String? ?? legacyMarkedBy ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String recordId;
  final String teacherUid;
  final String dateKey;
  final DateTime date;
  final AttendanceStatus status;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => recordId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'teacherUid': teacherUid,
      'dateKey': dateKey,
      'date': Timestamp.fromDate(date),
      'status': status.name,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
