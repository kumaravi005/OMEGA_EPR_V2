import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'report_template.dart';

final reportTemplateRepositoryProvider =
    Provider<FirestoreRepository<ReportTemplate>>((ref) {
      return FirestoreRepository<ReportTemplate>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.reportTemplates,
        fromFirestore: ReportTemplate.fromMap,
        toFirestore: (template) => template.toMap(),
      );
    });

/// Saved templates for one module's export screen, alphabetical by name.
final templatesForModuleProvider =
    StreamProvider.family<List<ReportTemplate>, ReportModule>((ref, module) {
      return ref
          .watch(reportTemplateRepositoryProvider)
          .watchAll()
          .map(
            (templates) =>
                templates.where((t) => t.module == module).toList()
                  ..sort((a, b) => a.name.compareTo(b.name)),
          );
    });
