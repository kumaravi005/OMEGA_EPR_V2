import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/report_layout_template.dart';
import '../data/report_layout_template_repository.dart';

class ReportLayoutTemplateFailure implements Exception {
  const ReportLayoutTemplateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final reportLayoutTemplateControllerProvider =
    Provider<ReportLayoutTemplateController>(
      (ref) => ReportLayoutTemplateController(ref),
    );

class ReportLayoutTemplateController {
  ReportLayoutTemplateController(this._ref);

  final Ref _ref;

  Future<String> create({
    required String name,
    required ReportHeaderConfig header,
    required ReportFooterConfig footer,
  }) async {
    try {
      final now = DateTime.now();
      return await _ref
          .read(reportLayoutTemplateRepositoryProvider)
          .add(
            ReportLayoutTemplate(
              templateId: '',
              name: name.trim(),
              header: header,
              footer: footer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const ReportLayoutTemplateFailure(
        'Could not save this template. Please try again.',
      );
    }
  }

  Future<void> update(
    ReportLayoutTemplate existing, {
    String? name,
    ReportHeaderConfig? header,
    ReportFooterConfig? footer,
  }) async {
    try {
      await _ref
          .read(reportLayoutTemplateRepositoryProvider)
          .set(
            existing.templateId,
            ReportLayoutTemplate(
              templateId: existing.templateId,
              name: (name ?? existing.name).trim(),
              header: header ?? existing.header,
              footer: footer ?? existing.footer,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      throw const ReportLayoutTemplateFailure(
        'Could not update this template. Please try again.',
      );
    }
  }

  Future<void> delete(ReportLayoutTemplate template) async {
    try {
      await _ref
          .read(reportLayoutTemplateRepositoryProvider)
          .delete(template.templateId);
    } catch (_) {
      throw const ReportLayoutTemplateFailure(
        'Could not delete this template. Please try again.',
      );
    }
  }
}
