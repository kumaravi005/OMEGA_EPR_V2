import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/report_template_controller.dart';
import '../../data/report_template.dart';
import '../../data/report_template_repository.dart';

/// "Save reusable export templates/configurations" - a load dropdown of
/// this module's saved templates plus a save/delete action, shared by
/// every export screen. [currentConfig] is called only when the admin
/// actually saves, so it can read whatever live form state the screen
/// currently holds; [onLoad] hands back a previously saved config map for
/// the screen to apply to its own filters/columns/sort/format state.
class TemplateBar extends ConsumerStatefulWidget {
  const TemplateBar({
    super.key,
    required this.module,
    required this.currentConfig,
    required this.onLoad,
  });

  final ReportModule module;
  final Map<String, dynamic> Function() currentConfig;
  final ValueChanged<Map<String, dynamic>> onLoad;

  @override
  ConsumerState<TemplateBar> createState() => _TemplateBarState();
}

class _TemplateBarState extends ConsumerState<TemplateBar> {
  ReportTemplate? _selected;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesForModuleProvider(widget.module));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: templatesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (templates) {
              if (templates.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No saved templates yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final selected = templates.contains(_selected) ? _selected : null;
              return DropdownButtonFormField<ReportTemplate>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Load a saved template',
                ),
                items: [
                  for (final template in templates)
                    DropdownMenuItem(
                      value: template,
                      child: Text(template.name),
                    ),
                ],
                onChanged: (template) {
                  setState(() => _selected = template);
                  if (template != null) widget.onLoad(template.config);
                },
              );
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (_selected != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete this template',
            onPressed: () => _delete(context, _selected!),
          ),
        AppButton(
          label: 'Save as template',
          variant: AppButtonVariant.secondary,
          onPressed: () => _save(context),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save export template'),
        content: AppTextField(
          controller: controller,
          label: 'Template name',
          hintText: 'e.g. Basic Student List',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(reportTemplateControllerProvider)
          .save(
            name: name,
            module: widget.module,
            config: widget.currentConfig(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "$name".')));
      }
    } on ReportTemplateFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, ReportTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${template.name}" will be removed.'),
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
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reportTemplateControllerProvider).delete(template);
      setState(() => _selected = null);
    } on ReportTemplateFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
