import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// Which export screen a saved template belongs to - templates from one
/// module are never offered on another's screen.
enum ReportModule {
  studentExport,
  feeDuesExport,
  testResultExport,
  // Added in Set 20.
  paymentReport;

  static ReportModule fromValue(String value) {
    return ReportModule.values.firstWhere(
      (module) => module.name == value,
      orElse: () => throw ArgumentError('Unknown report module: $value'),
    );
  }
}

/// A saved, reusable export configuration (e.g. "Basic Student List") -
/// the "save export configuration" requirement. [config] is a free-form
/// map whose shape is defined and interpreted entirely by the owning
/// export screen (selected columns, filters, sort, mode, format) - this
/// model doesn't need to know what's in it.
class ReportTemplate implements FirestoreDocument {
  const ReportTemplate({
    required this.templateId,
    required this.name,
    required this.module,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportTemplate.fromMap(String id, Map<String, dynamic> map) {
    return ReportTemplate(
      templateId: id,
      name: map['name'] as String,
      module: ReportModule.fromValue(map['module'] as String),
      config: Map<String, dynamic>.from(map['config'] as Map),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String templateId;
  final String name;
  final ReportModule module;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => templateId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'module': module.name,
      'config': config,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
