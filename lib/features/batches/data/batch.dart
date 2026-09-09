import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A named group students are admitted into (e.g. "Class 5 - Science
/// Morning"), carrying the standard fee students in it are expected to
/// pay before any per-student discount/adjustment.
class Batch implements FirestoreDocument {
  const Batch({
    required this.batchId,
    required this.name,
    required this.standardMonthlyFee,
    required this.standardInstallmentFee,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Batch.fromMap(String id, Map<String, dynamic> map) {
    return Batch(
      batchId: id,
      name: map['name'] as String,
      standardMonthlyFee: (map['standardMonthlyFee'] as num).toDouble(),
      standardInstallmentFee: (map['standardInstallmentFee'] as num).toDouble(),
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String batchId;
  final String name;
  final double standardMonthlyFee;
  final double standardInstallmentFee;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => batchId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'standardMonthlyFee': standardMonthlyFee,
      'standardInstallmentFee': standardInstallmentFee,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
