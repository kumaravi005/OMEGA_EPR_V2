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
    required this.markedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherAttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return TeacherAttendanceRecord(
      recordId: id,
      teacherUid: map['teacherUid'] as String,
      dateKey: map['dateKey'] as String,
      date: (map['date'] as Timestamp).toDate(),
      status: AttendanceStatus.fromValue(map['status'] as String),
      markedBy: map['markedBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String recordId;
  final String teacherUid;
  final String dateKey;
  final DateTime date;
  final AttendanceStatus status;
  final String markedBy;
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
      'markedBy': markedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
