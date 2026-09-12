import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_repository.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_stats.dart';
import '../data/student_attendance_record.dart';

/// Admin's student attendance history: filter by academic session, class,
/// batch and a date range, and see each matching student's present/
/// absent/percentage over that window - computed on demand from the raw
/// records (Set 13 spec), never a stored counter.
class StudentAttendanceReportScreen extends ConsumerStatefulWidget {
  const StudentAttendanceReportScreen({super.key});

  @override
  ConsumerState<StudentAttendanceReportScreen> createState() =>
      _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState
    extends ConsumerState<StudentAttendanceReportScreen> {
  String? _sessionId;
  String? _classId;
  String? _batchId;
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();

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
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final recordsAsync = ref.watch(allStudentAttendanceProvider);
    final studentsAsync = ref.watch(allStudentsProvider);

    final batches = batchesAsync.valueOrNull ?? const [];
    final matchingBatches = batches
        .where(
          (b) =>
              (_sessionId == null || b.academicSessionId == _sessionId) &&
              (_classId == null || b.classId == _classId),
        )
        .toList();
    if (_batchId != null && !matchingBatches.any((b) => b.batchId == _batchId)) {
      _batchId = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Student attendance history')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: sessionsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) =>
                              const SizedBox.shrink(),
                          data: (sessions) => DropdownButtonFormField<String?>(
                            initialValue: _sessionId,
                            decoration: const InputDecoration(
                              labelText: 'Session (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All sessions'),
                              ),
                              for (final session in sessions)
                                DropdownMenuItem<String?>(
                                  value: session.sessionId,
                                  child: Text(session.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _sessionId = value;
                              _batchId = null;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: classesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) =>
                              const SizedBox.shrink(),
                          data: (classes) => DropdownButtonFormField<String?>(
                            initialValue: _classId,
                            decoration: const InputDecoration(
                              labelText: 'Class (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All classes'),
                              ),
                              for (final schoolClass in classes)
                                DropdownMenuItem<String?>(
                                  value: schoolClass.classId,
                                  child: Text(schoolClass.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _classId = value;
                              _batchId = null;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('batch-$_sessionId-$_classId'),
                    initialValue: _batchId,
                    decoration: const InputDecoration(
                      labelText: 'Batch (all)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All matching batches'),
                      ),
                      for (final batch in matchingBatches)
                        DropdownMenuItem<String?>(
                          value: batch.batchId,
                          child: Text(batch.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _batchId = value),
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
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: recordsAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load attendance.\n$error'),
                data: (allRecords) {
                  final scoped = allRecords.where((r) {
                    if (!_inRange(r.date)) return false;
                    if (_batchId != null) return r.batchId == _batchId;
                    if (_sessionId != null &&
                        r.academicSessionId.isNotEmpty &&
                        r.academicSessionId != _sessionId) {
                      return false;
                    }
                    if (_classId != null &&
                        r.classId.isNotEmpty &&
                        r.classId != _classId) {
                      return false;
                    }
                    if (_sessionId == null && _classId == null) return true;
                    // A pre-Set-13 record has no session/class snapshot -
                    // fall back to resolving it via its batch so historical
                    // records still show up under a session/class filter.
                    if (r.academicSessionId.isEmpty || r.classId.isEmpty) {
                      final batch = batches
                          .where((b) => b.batchId == r.batchId)
                          .firstOrNull;
                      if (batch == null) return false;
                      if (_sessionId != null &&
                          batch.academicSessionId != _sessionId) {
                        return false;
                      }
                      if (_classId != null && batch.classId != _classId) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  if (scoped.isEmpty) {
                    return const EmptyView(
                      message: 'No attendance recorded for these filters.',
                    );
                  }

                  final students = studentsAsync.valueOrNull ?? const [];
                  final perStudent = <String, List<AttendanceStatus>>{};
                  for (final record in scoped) {
                    record.records.forEach((uid, status) {
                      perStudent.putIfAbsent(uid, () => []).add(status);
                    });
                  }
                  final rows =
                      perStudent.entries.map((entry) {
                          final student = students
                              .where((s) => s.uid == entry.key)
                              .firstOrNull;
                          final stats = computeAttendanceStats(entry.value);
                          return (
                            name: student?.name ?? entry.key,
                            admissionNumber: student?.admissionNumber ?? '',
                            stats: stats,
                          );
                        }).toList()
                        ..sort((a, b) => a.name.compareTo(b.name));

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Text(
                        '${scoped.length} attendance day(s) marked in range',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final row in rows)
                        Card(
                          child: ListTile(
                            title: Text(row.name),
                            subtitle: row.admissionNumber.isEmpty
                                ? null
                                : Text('Adm. no. ${row.admissionNumber}'),
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
          ],
        ),
      ),
    );
  }
}
