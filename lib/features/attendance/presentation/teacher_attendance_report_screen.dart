import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/export/export_dataset.dart';
import '../../../core/export/export_format.dart';
import '../../../core/export/export_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/error_formatting.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../teacher/data/teacher_repository.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_stats.dart';
import '../data/teacher_attendance_record.dart';

/// Admin's teacher attendance history: a date range and each teacher's
/// present/absent/percentage over that window - computed on demand,
/// never a stored counter (Set 13 spec).
class TeacherAttendanceReportScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceReportScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceReportScreen> createState() =>
      _TeacherAttendanceReportScreenState();
}

class _TeacherAttendanceReportScreenState
    extends ConsumerState<TeacherAttendanceReportScreen> {
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();

  /// The rows [build] most recently rendered - see the identical field on
  /// `StudentAttendanceReportScreen` for why this is cached rather than
  /// recomputed in the export handler.
  List<({String name, AttendanceStats stats})> _lastRows = const [];
  bool _isExporting = false;

  Future<void> _export(ExportFormat format) async {
    if (_lastRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this range.')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final dataset = ExportDataset(
        title: 'Teacher Attendance Report',
        subtitle: '${dateKey(_from)} - ${dateKey(_to)} | Total: ${_lastRows.length}',
        columns: const ['Teacher', 'Present', 'Absent', 'Percentage'],
        rows: [
          for (final row in _lastRows)
            [
              row.name,
              '${row.stats.present}',
              '${row.stats.absent}',
              row.stats.percentage == null ? '-' : '${row.stats.percentage!.toStringAsFixed(1)}%',
            ],
        ],
      );
      await const ExportService().export(dataset, format, fileName: 'teacher_attendance_report');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorText('Could not generate the export.\n$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_from.year - 2),
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

  bool _inRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(_from) && !day.isAfter(_to);
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(allTeachersProvider);
    final recordsAsync = ref.watch(allTeacherAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher attendance history'),
        actions: [
          PopupMenuButton<ExportFormat>(
            enabled: !_isExporting,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onSelected: _export,
            itemBuilder: (context) => [
              for (final format in ExportFormat.values)
                PopupMenuItem(value: format, child: Text(format.label)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
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
            ),
            const Divider(height: 1),
            Expanded(
              child: teachersAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load teachers.\n$error'),
                data: (teachers) => recordsAsync.when(
                  loading: () => const LoadingView(),
                  error: (error, stackTrace) => ErrorView(
                    message: 'Could not load attendance.\n$error',
                  ),
                  data: (allRecords) {
                    final scoped = allRecords
                        .where((r) => _inRange(r.date))
                        .toList();
                    if (scoped.isEmpty) {
                      _lastRows = const [];
                      return const EmptyView(
                        message: 'No attendance recorded for this range.',
                      );
                    }

                    final perTeacher = <String, List<TeacherAttendanceRecord>>{};
                    for (final record in scoped) {
                      perTeacher
                          .putIfAbsent(record.teacherUid, () => [])
                          .add(record);
                    }

                    final rows =
                        perTeacher.entries.map((entry) {
                            final teacher = teachers
                                .where((t) => t.uid == entry.key)
                                .firstOrNull;
                            final stats = computeAttendanceStats(
                              entry.value.map((r) => r.status),
                            );
                            return (
                              name: teacher?.name ?? entry.key,
                              stats: stats,
                            );
                          }).toList()
                          ..sort((a, b) => a.name.compareTo(b.name));
                    _lastRows = rows;

                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        for (final row in rows)
                          Card(
                            child: ListTile(
                              title: Text(row.name),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'P: ${row.stats.present}  A: ${row.stats.absent}',
                                  ),
                                  Text(
                                    row.stats.percentage == null
                                        ? '-'
                                        : '${row.stats.percentage!.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
