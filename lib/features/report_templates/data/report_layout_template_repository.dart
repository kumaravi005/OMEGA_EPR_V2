import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'report_layout_template.dart';

final reportLayoutTemplateRepositoryProvider = Provider<FirestoreRepository<ReportLayoutTemplate>>((ref) {
  return FirestoreRepository<ReportLayoutTemplate>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.reportLayoutTemplates,
    fromFirestore: ReportLayoutTemplate.fromMap,
    toFirestore: (template) => template.toMap(),
  );
});

/// Every saved layout template, alphabetical by name - for the designer's
/// list screen and every export screen's "Report layout" picker.
final allReportLayoutTemplatesProvider = StreamProvider<List<ReportLayoutTemplate>>((ref) {
  return ref
      .watch(reportLayoutTemplateRepositoryProvider)
      .watchAll()
      .map((templates) => templates.toList()..sort((a, b) => a.name.compareTo(b.name)));
});
