import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/export/export_dataset.dart';
import '../../../core/export/export_format.dart';
import '../../../core/export/export_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_formatting.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../fees/data/fee_calculator.dart';
import '../../fees/data/fee_payment_repository.dart';
import '../../report_templates/data/report_layout_template_repository.dart';
import '../../report_templates/presentation/widgets/report_layout_picker.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../data/report_template.dart';
import '../data/student_report_columns.dart';
import 'widgets/column_picker.dart';
import 'widgets/format_and_orientation_picker.dart';
import 'widgets/template_bar.dart';

enum StudentSortKey {
  name('Name'),
  className('Class'),
  due('Due');

  const StudentSortKey(this.label);
  final String label;
}

/// Student Data Export (Set 6, filters completed in Set 20 section 2:
/// session/class/board/active-status/name search, alongside the existing
/// batch filter) - search, column selection, sort, format/orientation,
/// save/load template, row-building, PDF/Excel/DOCX rendering all live
/// here, not duplicated per report.
class StudentReportExportScreen extends ConsumerStatefulWidget {
  const StudentReportExportScreen({
    super.key,
    required this.appBarTitle,
    required this.module,
    required this.datasetTitle,
    required this.exportFileName,
    required this.defaultColumns,
    this.defaultSortKey = StudentSortKey.name,
    this.defaultSortAscending = true,
  });

  final String appBarTitle;
  final ReportModule module;
  final String datasetTitle;
  final String exportFileName;
  final Set<String> defaultColumns;
  final StudentSortKey defaultSortKey;
  final bool defaultSortAscending;

  @override
  ConsumerState<StudentReportExportScreen> createState() =>
      _StudentReportExportScreenState();
}

class _StudentReportExportScreenState
    extends ConsumerState<StudentReportExportScreen> {
  final _searchController = TextEditingController();
  String? _sessionId;
  String? _classId;
  String? _boardId;
  String? _batchId;
  bool _activeOnly = true;
  late Set<String> _selectedColumns;
  late StudentSortKey _sortKey;
  late bool _sortAscending;
  ExportFormat _format = ExportFormat.pdf;
  ReportOrientation _orientation = ReportOrientation.auto;
  String? _layoutTemplateId;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedColumns = Set.of(widget.defaultColumns);
    _sortKey = widget.defaultSortKey;
    _sortAscending = widget.defaultSortAscending;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _currentConfig() => {
    'sessionId': _sessionId,
    'classId': _classId,
    'boardId': _boardId,
    'batchId': _batchId,
    'activeOnly': _activeOnly,
    'columns': _selectedColumns.toList(),
    'sortKey': _sortKey.name,
    'sortAscending': _sortAscending,
    'format': _format.name,
    'orientation': _orientation.name,
    'layoutTemplateId': _layoutTemplateId,
  };

  void _applyConfig(Map<String, dynamic> config) {
    setState(() {
      _sessionId = config['sessionId'] as String?;
      _classId = config['classId'] as String?;
      _boardId = config['boardId'] as String?;
      _batchId = config['batchId'] as String?;
      _activeOnly = config['activeOnly'] as bool? ?? true;
      _selectedColumns = Set<String>.from(
        config['columns'] as List? ?? widget.defaultColumns,
      );
      _sortKey = StudentSortKey.values.firstWhere(
        (key) => key.name == config['sortKey'],
        orElse: () => widget.defaultSortKey,
      );
      _sortAscending =
          config['sortAscending'] as bool? ?? widget.defaultSortAscending;
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

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final boardsAsync = ref.watch(allBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TemplateBar(
              module: widget.module,
              currentConfig: _currentConfig,
              onLoad: _applyConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchController,
              label: 'Search by name or account ID',
              suffixIcon: const Icon(Icons.search),
            ),
            const SizedBox(height: AppSpacing.sm),
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active students only'),
              value: _activeOnly,
              onChanged: (value) => setState(() => _activeOnly = value ?? true),
            ),
            const SizedBox(height: AppSpacing.md),
            ColumnPicker(
              options: StudentReportColumns.all,
              selectedKeys: _selectedColumns,
              onChanged: (keys) => setState(() => _selectedColumns = keys),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StudentSortKey>(
                    initialValue: _sortKey,
                    decoration: const InputDecoration(labelText: 'Sort by'),
                    items: [
                      for (final key in StudentSortKey.values)
                        DropdownMenuItem(value: key, child: Text(key.label)),
                    ],
                    onChanged: (key) =>
                        setState(() => _sortKey = key ?? _sortKey),
                  ),
                ),
                IconButton(
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () =>
                      setState(() => _sortAscending = !_sortAscending),
                ),
              ],
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
              onPressed:
                  studentsAsync.valueOrNull == null ||
                      batchesAsync.valueOrNull == null
                  ? null
                  : () => _generate(
                      studentsAsync.valueOrNull!,
                      batchesAsync.valueOrNull!,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(
    List<StudentProfile> students,
    List<Batch> batches,
  ) async {
    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one column.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final batchNames = {
        for (final batch in batches) batch.batchId: batch.name,
      };
      final search = _searchController.text.trim().toLowerCase();

      final filtered = students.where((student) {
        if (_activeOnly && !student.active) return false;
        if (_sessionId != null && student.academicSessionId != _sessionId) return false;
        if (_classId != null && student.classId != _classId) return false;
        if (_boardId != null && student.boardId != _boardId) return false;
        if (_batchId != null && student.batchId != _batchId) return false;
        if (search.isNotEmpty) {
          final matchesName = student.name.toLowerCase().contains(search);
          final matchesId = student.accountId.toLowerCase().contains(search);
          if (!matchesName && !matchesId) return false;
        }
        return true;
      }).toList();

      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No students match these filters.')),
          );
        }
        return;
      }

      final rows = <StudentReportRow>[];
      for (final student in filtered) {
        final legacyPayments = await ref
            .read(paymentRepositoryProvider(student.uid))
            .getAll();
        // Combined with the Set 19 `feePayments` ledger (active only) so
        // this export stays accurate for payments recorded after Set 19,
        // not just the legacy subcollection - see
        // docs/database-architecture.md's "Fee Collection & Payment
        // Management (Set 19)".
        final feePayments = await ref
            .read(feePaymentRepositoryProvider)
            .getWhere((query) => query.where('studentId', isEqualTo: student.uid));
        rows.add(
          StudentReportRow(
            student: student,
            batchName: batchNames[student.batchId] ?? student.batchId,
            paid: combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments),
            due: combinedBalanceDue(
              finalFee: student.finalFee,
              feePayments: feePayments,
              legacyPayments: legacyPayments,
            ),
          ),
        );
      }

      rows.sort((a, b) {
        final result = switch (_sortKey) {
          StudentSortKey.name => a.student.name.compareTo(b.student.name),
          StudentSortKey.className => a.student.className.compareTo(
            b.student.className,
          ),
          StudentSortKey.due => a.due.compareTo(b.due),
        };
        return _sortAscending ? result : -result;
      });

      // Fetched fresh (not from a watched/cached provider) right before
      // rendering, and baked into `ExportDataset.branding` as a
      // one-time snapshot - if the template is edited later, this
      // already-generated report is unaffected (see ReportBranding's
      // doc comment).
      final branding = _layoutTemplateId == null
          ? null
          : (await ref
                    .read(reportLayoutTemplateRepositoryProvider)
                    .getById(_layoutTemplateId!))
                ?.toBranding();

      final orderedKeys = StudentReportColumns.orderedKeys(_selectedColumns);
      final dataset = ExportDataset(
        title: widget.datasetTitle,
        subtitle: [
          if (_batchId != null) 'Batch: ${batchNames[_batchId] ?? _batchId}',
          'Total: ${rows.length}',
        ].join(' | '),
        columns: [
          for (final key in orderedKeys)
            StudentReportColumns.all.firstWhere((c) => c.key == key).label,
        ],
        rows: [
          for (final row in rows) StudentReportColumns.row(row, orderedKeys),
        ],
        orientation: _orientation,
        branding: branding,
      );

      await const ExportService().export(
        dataset,
        _format,
        fileName: widget.exportFileName,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorText('Could not generate the export.\n$error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
