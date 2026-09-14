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
import '../../auth/data/user_account_repository.dart';
import '../../batches/data/batch_repository.dart';
import '../../fees/data/fee_payment_repository.dart';
import '../../report_templates/data/report_layout_template_repository.dart';
import '../../report_templates/presentation/widgets/report_layout_picker.dart';
import '../../student/data/payment.dart';
import '../../student/data/student_repository.dart';
import '../data/payment_report_columns.dart';
import '../data/report_template.dart';
import 'widgets/column_picker.dart';
import 'widgets/format_and_orientation_picker.dart';
import 'widgets/template_bar.dart';

enum _StatusFilter { all, active, reversed }

/// Payment Report (Set 20 section 6) - Set 19's `feePayments` ledger,
/// filtered by session/class/batch/date range/mode/student, never
/// recalculated or re-derived. Reversed payments stay visible with their
/// status rather than being hidden by default.
class PaymentReportScreen extends ConsumerStatefulWidget {
  const PaymentReportScreen({super.key});

  @override
  ConsumerState<PaymentReportScreen> createState() => _PaymentReportScreenState();
}

class _PaymentReportScreenState extends ConsumerState<PaymentReportScreen> {
  final _searchController = TextEditingController();
  String? _sessionId;
  String? _classId;
  String? _batchId;
  PaymentMode? _mode;
  _StatusFilter _statusFilter = _StatusFilter.all;
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  Set<String> _selectedColumns = Set.of(PaymentReportColumns.defaultKeys);
  ExportFormat _format = ExportFormat.pdf;
  ReportOrientation _orientation = ReportOrientation.auto;
  String? _layoutTemplateId;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_from.year - 5),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  Map<String, dynamic> _currentConfig() => {
    'sessionId': _sessionId,
    'classId': _classId,
    'batchId': _batchId,
    'mode': _mode?.name,
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
      final modeName = config['mode'] as String?;
      _mode = modeName == null
          ? null
          : PaymentMode.values.firstWhere(
              (m) => m.name == modeName,
              orElse: () => PaymentMode.cash,
            );
      _statusFilter = _StatusFilter.values.firstWhere(
        (s) => s.name == config['statusFilter'],
        orElse: () => _StatusFilter.all,
      );
      _selectedColumns = Set<String>.from(
        config['columns'] as List? ?? PaymentReportColumns.defaultKeys,
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

  bool _inRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(_from) && !day.isAfter(_to);
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(allFeePaymentsProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TemplateBar(
              module: ReportModule.paymentReport,
              currentConfig: _currentConfig,
              onLoad: _applyConfig,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchController,
              label: 'Search by student name',
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
                  child: DropdownButtonFormField<PaymentMode?>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Mode (all)'),
                    items: [
                      const DropdownMenuItem<PaymentMode?>(value: null, child: Text('All modes')),
                      for (final mode in PaymentMode.values)
                        DropdownMenuItem<PaymentMode?>(value: mode, child: Text(mode.label)),
                    ],
                    onChanged: (value) => setState(() => _mode = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  '${'${_from.toLocal()}'.split(' ').first} - '
                  '${'${_to.toLocal()}'.split(' ').first}',
                ),
              ),
            ),
            SegmentedButton<_StatusFilter>(
              segments: const [
                ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                ButtonSegment(value: _StatusFilter.active, label: Text('Active')),
                ButtonSegment(value: _StatusFilter.reversed, label: Text('Reversed')),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (selection) => setState(() => _statusFilter = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            ColumnPicker(
              options: PaymentReportColumns.all,
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
              onPressed: paymentsAsync.valueOrNull == null ? null : _generate,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one column.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final payments = ref.read(allFeePaymentsProvider).valueOrNull ?? const [];
      final students = await ref.read(studentRepositoryProvider).getAll();
      final classes = ref.read(allSchoolClassesProvider).valueOrNull ?? const [];
      final batches = ref.read(allBatchesProvider).valueOrNull ?? const [];
      final admins = await ref.read(userAccountRepositoryProvider).getAll();

      final studentById = {for (final s in students) s.uid: s};
      final classNameById = {for (final c in classes) c.classId: c.name};
      final batchNameById = {for (final b in batches) b.batchId: b.name};
      final adminNameById = {for (final a in admins) a.uid: a.displayName};
      final search = _searchController.text.trim().toLowerCase();

      final filtered = payments.where((payment) {
        if (!_inRange(payment.paymentDate)) return false;
        if (_sessionId != null && payment.academicSessionId != _sessionId) return false;
        if (_classId != null && payment.classId != _classId) return false;
        if (_batchId != null && payment.batchId != _batchId) return false;
        if (_mode != null && payment.mode != _mode) return false;
        final matchesStatus = switch (_statusFilter) {
          _StatusFilter.all => true,
          _StatusFilter.active => !payment.isReversed,
          _StatusFilter.reversed => payment.isReversed,
        };
        if (!matchesStatus) return false;
        if (search.isNotEmpty) {
          final name = studentById[payment.studentId]?.name.toLowerCase() ?? '';
          if (!name.contains(search)) return false;
        }
        return true;
      }).toList()
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No payments match these filters.')),
          );
        }
        return;
      }

      final rows = [
        for (final payment in filtered)
          PaymentReportRow(
            payment: payment,
            studentName: studentById[payment.studentId]?.name ?? payment.studentId,
            admissionNumber: studentById[payment.studentId]?.admissionNumber ?? '',
            className: classNameById[payment.classId] ?? payment.classId,
            batchName: batchNameById[payment.batchId] ?? payment.batchId,
            collectedByName: adminNameById[payment.collectedBy] ?? payment.collectedBy,
          ),
      ];

      final branding = _layoutTemplateId == null
          ? null
          : (await ref
                    .read(reportLayoutTemplateRepositoryProvider)
                    .getById(_layoutTemplateId!))
                ?.toBranding();

      final orderedKeys = PaymentReportColumns.orderedKeys(_selectedColumns);
      final dataset = ExportDataset(
        title: 'Payment Report',
        subtitle: [
          '${'${_from.toLocal()}'.split(' ').first} - ${'${_to.toLocal()}'.split(' ').first}',
          if (_batchId != null) 'Batch: ${batchNameById[_batchId] ?? _batchId}',
          'Total: ${rows.length}',
        ].join(' | '),
        columns: [
          for (final key in orderedKeys)
            PaymentReportColumns.all.firstWhere((c) => c.key == key).label,
        ],
        rows: [for (final row in rows) PaymentReportColumns.row(row, orderedKeys)],
        orientation: _orientation,
        branding: branding,
      );

      await const ExportService().export(dataset, _format, fileName: 'payment_report');
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
