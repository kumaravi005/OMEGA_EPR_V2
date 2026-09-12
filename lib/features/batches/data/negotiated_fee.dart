import 'package:cloud_firestore/cloud_firestore.dart';

/// The "standard fee vs. final agreed fee" record a future Student
/// Admission set will attach to one student - the reusable model
/// Set 10 is asked to design, not to persist or expose through any UI
/// yet (see docs/database-architecture.md's "Standard fee vs. final
/// agreed fee" for the full rationale).
///
/// [standardFee] is a **snapshot** of the batch's `standardFeeFor(...)`
/// at the moment this record is created - never a live reference to the
/// batch. That's what guarantees "the batch's standard fee must remain
/// unchanged" when a student gets a discount: nothing here ever writes
/// back to the `Batch` document, and nothing on `Batch` ever reads this.
///
/// Not a [FirestoreDocument] on purpose - Set 10 has nowhere to persist
/// this yet (no admission record exists to attach it to), so this is a
/// plain value object a future set adopts wholesale (fromMap/toMap are
/// still provided so that adoption is a copy-paste, not a rewrite).
class NegotiatedFee {
  const NegotiatedFee({
    required this.standardFee,
    required this.finalFee,
    required this.isInstallmentPlan,
    this.remark,
    this.effectiveDate,
    required this.configuredByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NegotiatedFee.fromMap(Map<String, dynamic> map) {
    return NegotiatedFee(
      standardFee: (map['standardFee'] as num).toDouble(),
      finalFee: (map['finalFee'] as num).toDouble(),
      isInstallmentPlan: map['isInstallmentPlan'] as bool,
      remark: map['remark'] as String?,
      effectiveDate: (map['effectiveDate'] as Timestamp?)?.toDate(),
      configuredByUid: map['configuredByUid'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// A snapshot of the batch's standard fee at the time this was
  /// configured - see the class doc comment for why this is never a
  /// live reference.
  final double standardFee;

  /// The figure actually agreed with the family - what every future
  /// payment/due calculation would use, never [standardFee].
  final double finalFee;
  final bool isInstallmentPlan;

  /// Required whenever [finalFee] differs from [standardFee] - enforced
  /// by whichever future form/rule adopts this model, not here (this is
  /// a plain value object with no validation of its own).
  final String? remark;

  /// When the agreed fee takes effect, if that ever needs to differ from
  /// [createdAt] (e.g. a discount approved mid-session, backdated to the
  /// start of a term). Optional - most records won't need it.
  final DateTime? effectiveDate;

  /// The admin `uid` who configured this - "who configured it", per the
  /// spec.
  final String configuredByUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Positive = a discount was given, negative = the family agreed to
  /// pay more than standard (rare, but not disallowed), zero = no
  /// change from standard.
  double get discountAmount => standardFee - finalFee;

  Map<String, dynamic> toMap() {
    return {
      'standardFee': standardFee,
      'finalFee': finalFee,
      'isInstallmentPlan': isInstallmentPlan,
      'remark': remark,
      'effectiveDate': effectiveDate == null
          ? null
          : Timestamp.fromDate(effectiveDate!),
      'configuredByUid': configuredByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
