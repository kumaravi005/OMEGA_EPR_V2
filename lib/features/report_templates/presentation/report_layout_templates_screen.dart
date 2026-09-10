import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/report_layout_template_controller.dart';
import '../data/report_layout_template.dart';
import '../data/report_layout_template_repository.dart';

/// Admin's list of saved report-layout templates - create new, edit, or
/// delete. Deleting one never touches a report already generated with it
/// (see [ReportBranding]'s doc comment for why).
class ReportLayoutTemplatesScreen extends ConsumerWidget {
  const ReportLayoutTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(allReportLayoutTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Report templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminReportTemplateNew),
        tooltip: 'New template',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: templatesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load report templates.\n$error'),
          data: (templates) {
            if (templates.isEmpty) {
              return const EmptyView(
                message: 'No report templates yet. Tap + to design one.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: templates.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _TemplateTile(template: templates[index]),
            );
          },
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});

  final ReportLayoutTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(template.name),
        subtitle: Text(_summary()),
        onTap: () => context.push(
          '${AppRoutes.adminReportTemplates}/${template.templateId}/edit',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ),
    );
  }

  String _summary() {
    final parts = <String>[
      if (template.header.logoUrl != null &&
          template.header.logoUrl!.isNotEmpty)
        'Logo',
      if (template.footer.showSignature) 'Signature',
      if (template.footer.showPageNumber) 'Page numbers',
    ];
    return parts.isEmpty ? 'Header/footer template' : parts.join(' - ');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          '"${template.name}" will be removed. Reports already generated with it are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(reportLayoutTemplateControllerProvider).delete(template);
    } on ReportLayoutTemplateFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
