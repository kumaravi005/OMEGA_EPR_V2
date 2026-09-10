import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/report_template.dart';
import '../data/report_template_repository.dart';

class ReportTemplateFailure implements Exception {
  const ReportTemplateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final reportTemplateControllerProvider = Provider<ReportTemplateController>(
  (ref) => ReportTemplateController(ref),
);

class ReportTemplateController {
  ReportTemplateController(this._ref);

  final Ref _ref;

  Future<void> save({
    required String name,
    required ReportModule module,
    required Map<String, dynamic> config,
  }) async {
    try {
      final now = DateTime.now();
      await _ref
          .read(reportTemplateRepositoryProvider)
          .add(
            ReportTemplate(
              templateId: '',
              name: name.trim(),
              module: module,
              config: config,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const ReportTemplateFailure(
        'Could not save this template. Please try again.',
      );
    }
  }

  Future<void> delete(ReportTemplate template) async {
    try {
      await _ref
          .read(reportTemplateRepositoryProvider)
          .delete(template.templateId);
    } catch (_) {
      throw const ReportTemplateFailure(
        'Could not delete this template. Please try again.',
      );
    }
  }
}
