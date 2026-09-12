import 'package:cloud_firestore/cloud_firestore.dart';

enum InstallmentStatus {
  pending,
  paid;

  static InstallmentStatus fromValue(String value) {
    return InstallmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown installment status: $value'),
    );
  }

  String get label => this == InstallmentStatus.paid ? 'Paid' : 'Pending';
}

/// One row of a student's installment schedule (e.g. "Admission -
/// Rs. 2000 - due 10 April"). A batch only ever configures a single
/// *standard* installment/course fee (`Batch.standardInstallmentFee`) -
/// this is what lets a student's own installment plan break that into a
/// custom sequence of amounts/dates without touching the batch's
/// standard configuration. Embedded directly in `StudentAdmission.
/// installments` (Set 11) - see docs/database-architecture.md.
///
/// Not a [FirestoreDocument] on its own - it only ever exists nested
/// inside a `StudentAdmission` document, never as a document of its own.
class InstallmentScheduleItem {
  const InstallmentScheduleItem({
    required this.label,
    required this.amount,
    required this.dueDate,
    this.status = InstallmentStatus.pending,
  });

  factory InstallmentScheduleItem.fromMap(Map<String, dynamic> map) {
    return InstallmentScheduleItem(
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: InstallmentStatus.fromValue(map['status'] as String),
    );
  }

  final String label;
  final double amount;
  final DateTime dueDate;
  final InstallmentStatus status;

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.name,
    };
  }
}
