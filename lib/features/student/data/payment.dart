import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum PaymentMode {
  cash,
  upi,
  bankTransfer,
  cheque,
  other;

  static PaymentMode fromValue(String value) {
    return PaymentMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => throw ArgumentError('Unknown payment mode: $value'),
    );
  }

  String get label => switch (this) {
    PaymentMode.cash => 'Cash',
    PaymentMode.upi => 'UPI',
    PaymentMode.bankTransfer => 'Bank transfer',
    PaymentMode.cheque => 'Cheque',
    PaymentMode.other => 'Other',
  };
}

/// One fee payment recorded against a student, stored at
/// `students/{uid}/payments/{paymentId}`.
class Payment implements FirestoreDocument {
  const Payment({
    required this.paymentId,
    required this.amount,
    required this.date,
    required this.mode,
    required this.remark,
    required this.createdAt,
    required this.createdBy,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      paymentId: id,
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      mode: PaymentMode.fromValue(map['mode'] as String),
      remark: map['remark'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] as String,
    );
  }

  final String paymentId;
  final double amount;
  final DateTime date;
  final PaymentMode mode;
  final String? remark;
  final DateTime createdAt;
  final String createdBy;

  @override
  String get id => paymentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'mode': mode.name,
      'remark': remark,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
