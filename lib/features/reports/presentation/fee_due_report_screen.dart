import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/export/export_dataset.dart';
import '../../../core/export/export_format.dart';
import '../../../core/export/export_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_formatting.dart';
import '../../../core/widgets/app_button.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../../fees/data/fee_calculator.dart';
import '../../fees/data/fee_summary.dart';
import '../../report_templates/data/report_layout_template_repository.dart';
import '../../report_templates/presentation/widgets/report_layout_picker.dart';
import '../data/fee_report_columns.dart';
import '../data/report_template.dart';
import 'widgets/column_picker.dart';
import 'widgets/format_and_orientation_picker.dart';
import 'widgets/template_bar.dart';

enum _StatusFilter { all, paid, partiallyPaid, due, overdue }

/// Fee Due Report (Set 20 section 4) - session/class/batch/board/status
/// filters over Set 19's `allStudentFeeSummariesProvider` (never a new fee
/// formula - "use the existing Set 19 fee calculations"), with an
/// admin-controlled column selection that doubles as the "telecaller/
/// staff print report" (section 5): pick just the contact-relevant
/// columns and this same report becomes that list, so nothing here
/// duplicates the other.
class FeeDueReportScreen extends ConsumerStatefulWidget {
  const FeeDueReportScreen({super.key});

  @override
  ConsumerState<FeeDueReportScreen> createState() => _FeeDueReportScreenState();
}

class _FeeDueReportScreenState extends ConsumerState<FeeDueReportScreen> {
  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _boardId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  Set<String> _selectedColumns = Set.of(FeeReportColumns.defaultFeeDueKeys);
  ExportFormat _format = ExportFormat.pdf;
  ReportOrientation _orientation = ReportOrientation.auto;
  String? _layoutTemplateId;
  bool _isGenerating = false;

  Map<String, dynamic> _currentConfig() => {
    'sessionId': _sessionId,
    'classId': _classId,
    'batchId': _batchId,
    'boardId': _boardId,
    'statusFilter': _statusFilter.name,
    'columns': _selectedColumns.toList(),
    'format': _format.name,
    'orientation': _orientation.name,
    'layoutTemplateId': _layoutTemplateId,
  };

  void _applyConfig(Map<String, dynamic> config) {
    setState(() {
      _sessionId = config['sessionId'] as String?;
      _classId = config['classId'] as String?;
      _batchId = config['batchId'] as String?;
      _boardId = config['boardId'] as String?;
      _statusFilter = _StatusFilter.values.firstWhere(
        (s) => s.name == config['statusFilter'],
        orElse: () => _StatusFilter.all,
      );
      _selectedColumns = Set<String>.from(
        config['columns'] as List? ?? FeeReportColumns.defaultFeeDueKeys,
      );
      _format = ExportFormat.values.firstWhere(
        (f) => f.name == config['format'],
        orElse: () => ExportFormat.pdf,
      );
      _orientation = ReportOrientation.values.firstWhere(
        (o) => o.name == config['orientation'],
        orElse: () => ReportOrientation.auto,
      );
      _layoutTemplateId = config['layoutTemplateId'] as String?;
    });
  }

  bool _matchesStatus(FeeStatus? status) => switch (_statusFilter) {
    _StatusFilter.all => true,
    _StatusFilter.paid => status == FeeStatus.paid,
    _StatusFilter.partiallyPaid => status == FeeStatus.partiallyPaid,
    _StatusFilter.due => status == FeeStatus.due,
    _StatusFilter.overdue => status == FeeStatus.overdue,
  };

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(allStudentFeeSummariesProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final boardsAsync = ref.watch(allBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fee due report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TemplateBar(
              module: ReportModule.feeDuesExport,
              currentConfig: _currentConfig,
              onLoad: _applyConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: sessionsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (sessions) => DropdownButtonFormField<String?>(
                      initialValue: _sessionId,
                      decoration: const InputDecoration(labelText: 'Session (all)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All sessions')),
                        for (final session in sessions)
                          DropdownMenuItem<String?>(value: session.sessionId, child: Text(session.name)),
                      ],
                      onChanged: (value) => setState(() => _sessionId = value),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: classesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (classes) => DropdownButtonFormField<String?>(
                      initialValue: _classId,
                      decoration: const InputDecoration(labelText: 'Class (all)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All classes')),
                        for (final schoolClass in classes)
                          DropdownMenuItem<String?>(value: schoolClass.classId, child: Text(schoolClass.name)),
                      ],
                      onChanged: (value) => setState(() => _classId = value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: batchesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (batches) => DropdownButtonFormField<String?>(
                      initialValue: _batchId,
                      decoration: const InputDecoration(labelText: 'Batch (all)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All batches')),
                        for (final batch in batches)
                          DropdownMenuItem<String?>(value: batch.batchId, child: Text(batch.name)),
                      ],
                      onChanged: (value) => setState(() => _batchId = value),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: boardsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (boards) => DropdownButtonFormField<String?>(
                      initialValue: _boardId,
                      decoration: const InputDecoration(labelText: 'Board (all)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All boards')),
                        for (final board in boards)
                          DropdownMenuItem<String?>(value: board.boardId, child: Text(board.name)),
                      ],
                      onChanged: (value) => setState(() => _boardId = value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_StatusFilter>(
                segments: const [
                  ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                  ButtonSegment(value: _StatusFilter.paid, label: Text('Paid')),
                  ButtonSegment(value: _StatusFilter.partiallyPaid, label: Text('Partial')),
                  ButtonSegment(value: _StatusFilter.due, label: Text('Due')),
                  ButtonSegment(value: _StatusFilter.overdue, label: Text('Overdue')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (selection) => setState(() => _statusFilter = selection.first),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () => setState(
                    () => _selectedColumns = Set.of(FeeReportColumns.defaultFeeDueKeys),
                  ),
                  child: const Text('Fee due report columns'),
                ),
                OutlinedButton(
                  onPressed: () => setState(
                    () => _selectedColumns = Set.of(FeeReportColumns.defaultStaffContactKeys),
                  ),
                  child: const Text('Staff contact list columns'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ColumnPicker(
              options: FeeReportColumns.all,
              selectedKeys: _selectedColumns,
              onChanged: (keys) => setState(() => _selectedColumns = keys),
            ),
            const SizedBox(height: AppSpacing.md),
            FormatPicker(
              value: _format,
              onChanged: (format) => setState(() => _format = format),
            ),
            const SizedBox(height: AppSpacing.md),
            OrientationPicker(
              value: _orientation,
              onChanged: (o) => setState(() => _orientation = o),
            ),
            const SizedBox(height: AppSpacing.md),
            ReportLayoutPicker(
              value: _layoutTemplateId,
              onChanged: (id) => setState(() => _layoutTemplateId = id),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Generate export',
              icon: Icons.file_download_outlined,
              isLoading: _isGenerating,
              onPressed: summariesAsync.valueOrNull == null
                  ? null
                  : () => _generate(summariesAsync.valueOrNull!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(List<StudentFeeSummary> summaries) async {
    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one column.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final batches = ref.read(allBatchesProvider).valueOrNull ?? const [];
      final batchNames = {for (final batch in batches) batch.batchId: batch.name};

      final filtered = summaries.where((summary) {
        final student = summary.student;
        if (_sessionId != null && student.academicSessionId != _sessionId) return false;
        if (_classId != null && student.classId != _classId) return false;
        if (_batchId != null && student.batchId != _batchId) return false;
        if (_boardId != null && student.boardId != _boardId) return false;
        return _matchesStatus(summary.status);
      }).toList()
        ..sort((a, b) => a.student.name.compareTo(b.student.name));

      final rows = [
        for (final summary in filtered)
          FeeReportRow(
            student: summary.student,
            admission: summary.admission,
            batchName: batchNames[summary.student.batchId] ?? summary.student.batchId,
            totalPaid: summary.totalPaid,
            balanceDue: summary.balanceDue,
            status: summary.status,
            lastPaymentDate: summary.lastPaymentDate,
          ),
      ];

      final branding = _layoutTemplateId == null
          ? null
          : (await ref
                    .read(reportLayoutTemplateRepositoryProvider)
                    .getById(_layoutTemplateId!))
                ?.toBranding();

      final orderedKeys = FeeReportColumns.orderedKeys(_selectedColumns);
      final dataset = ExportDataset(
        title: 'Fee Due Report',
        subtitle: [
          if (_batchId != null) 'Batch: ${batchNames[_batchId] ?? _batchId}',
          if (_statusFilter != _StatusFilter.all) 'Status: ${_statusFilter.name}',
          'Total: ${rows.length}',
        ].join(' | '),
        columns: [
          for (final key in orderedKeys)
            FeeReportColumns.all.firstWhere((c) => c.key == key).label,
        ],
        rows: [for (final row in rows) FeeReportColumns.row(row, orderedKeys)],
        orientation: _orientation,
        branding: branding,
      );

      await const ExportService().export(dataset, _format, fileName: 'fee_due_report');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorText('Could not generate the export.\n$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
