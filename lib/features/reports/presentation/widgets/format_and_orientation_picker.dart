import 'package:flutter/material.dart';
import '../../../../core/export/export_dataset.dart';
import '../../../../core/export/export_format.dart';
import '../../../../core/theme/app_spacing.dart';

/// Output-format picker (PDF/Excel/DOCX) - the same three formats, the
/// same widget, on every export screen.
class FormatPicker extends StatelessWidget {
  const FormatPicker({super.key, required this.value, required this.onChanged});

  final ExportFormat value;
  final ValueChanged<ExportFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Output format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<ExportFormat>(
          segments: [for (final format in ExportFormat.values) ButtonSegment(value: format, label: Text(format.label))],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

/// Page-orientation picker (PDF/DOCX). "Auto" follows the column-count
/// heuristic in [ExportDataset.isLandscape] - most admins never need to
/// touch this, but a manual override is offered since a report can be
/// wide in content even with few columns (long names, etc.).
class OrientationPicker extends StatelessWidget {
  const OrientationPicker({super.key, required this.value, required this.onChanged});

  final ReportOrientation value;
  final ValueChanged<ReportOrientation> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ReportOrientation>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Page orientation'),
      items: const [
        DropdownMenuItem(value: ReportOrientation.auto, child: Text('Auto (based on column count)')),
        DropdownMenuItem(value: ReportOrientation.portrait, child: Text('Portrait')),
        DropdownMenuItem(value: ReportOrientation.landscape, child: Text('Landscape')),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}
