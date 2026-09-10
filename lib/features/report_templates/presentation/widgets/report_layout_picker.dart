import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/report_layout_template_repository.dart';

/// Lets an export screen pick which saved [ReportLayoutTemplate] (Set 7)
/// to brand its output with - "template reuse", the same picker on every
/// compatible export screen instead of a bespoke one each. `null` means
/// "no template" - the export renders exactly as it did before Set 7.
class ReportLayoutPicker extends ConsumerWidget {
  const ReportLayoutPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(allReportLayoutTemplatesProvider);

    return templatesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (templates) => DropdownButtonFormField<String?>(
        initialValue: templates.any((t) => t.templateId == value) ? value : null,
        decoration: const InputDecoration(labelText: 'Report layout (optional)'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('No template (plain report)')),
          for (final template in templates) DropdownMenuItem<String?>(value: template.templateId, child: Text(template.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
