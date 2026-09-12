import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import '../../batches/data/installment_schedule_item.dart';
import 'student_profile.dart';

/// Turns a raw sequence number into the institute's admission-number
/// format. A separate, pure function (rather than inline string
/// formatting) so it's directly testable without touching Firestore -
/// see [SequenceService] for where the raw number comes from.
String formatAdmissionNumber(int sequenceNumber) =>
    'STU${sequenceNumber.toString().padLeft(4, '0')}';

/// One admission/enrollment event for a student - stored at
/// `students/{uid}/admissions/{admissionId}`, separate from the
/// student's own stable identity ([StudentProfile]) so a student who
/// returns in a future academic session, or moves batches, gets a NEW
/// admission record rather than an overwritten one.
///
/// [standardFee]/[finalFee]/[feeReason]/[paymentPlan]/[installments] are
/// all **snapshots** taken at the moment this admission was configured -
/// exactly like [StudentProfile.standardFee]/[Batch.standardFeeFor] never
/// writing back to the batch, nothing here is ever rewritten by a later
/// change to the batch's standard fee. Superseding this admission (e.g.
/// a batch transfer) creates a new [StudentAdmission] document and only
/// ever flips this one's [active] to `false` - the historical financial
/// agreement itself is never edited after creation (see
/// docs/database-architecture.md).
class StudentAdmission implements FirestoreDocument {
  const StudentAdmission({
    required this.admissionId,
    required this.studentUid,
    required this.academicSessionId,
    required this.classId,
    required this.batchId,
    this.boardId,
    this.boardCustomText,
    required this.standardFee,
    required this.finalFee,
    this.feeReason,
    required this.paymentPlan,
    required this.installments,
    required this.admissionDate,
    required this.active,
    required this.configuredByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentAdmission.fromMap(String id, Map<String, dynamic> map) {
    return StudentAdmission(
      admissionId: id,
      studentUid: map['studentUid'] as String,
      academicSessionId: map['academicSessionId'] as String,
      classId: map['classId'] as String,
      batchId: map['batchId'] as String,
      boardId: map['boardId'] as String?,
      boardCustomText: map['boardCustomText'] as String?,
      standardFee: (map['standardFee'] as num).toDouble(),
      finalFee: (map['finalFee'] as num).toDouble(),
      feeReason: map['feeReason'] as String?,
      paymentPlan: PaymentPlan.fromValue(map['paymentPlan'] as String),
      installments: (map['installments'] as List<dynamic>? ?? const [])
          .map((item) => InstallmentScheduleItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      admissionDate: (map['admissionDate'] as Timestamp).toDate(),
      active: map['active'] as bool,
      configuredByUid: map['configuredByUid'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String admissionId;
  final String studentUid;
  final String academicSessionId;
  final String classId;
  final String batchId;
  final String? boardId;
  final String? boardCustomText;
  final double standardFee;
  final double finalFee;
  final String? feeReason;
  final PaymentPlan paymentPlan;
  final List<InstallmentScheduleItem> installments;
  final DateTime admissionDate;

  /// `true` for the student's current admission; `false` once superseded
  /// by a later one (e.g. a batch transfer). Never deleted.
  final bool active;

  /// The admin `uid` who configured this admission's fee agreement.
  final String configuredByUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get discountAmount => standardFee - finalFee;

  @override
  String get id => admissionId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'batchId': batchId,
      'boardId': boardId,
      'boardCustomText': boardCustomText,
      'standardFee': standardFee,
      'finalFee': finalFee,
      'feeReason': feeReason,
      'paymentPlan': paymentPlan.name,
      'installments': installments.map((item) => item.toMap()).toList(),
      'admissionDate': Timestamp.fromDate(admissionDate),
      'active': active,
      'configuredByUid': configuredByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
