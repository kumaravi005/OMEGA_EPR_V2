import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_repository.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';

/// Admin marks one common attendance record per batch/date, covering
/// every student in the batch - never split by subject.
class MarkStudentAttendanceScreen extends ConsumerStatefulWidget {
  const MarkStudentAttendanceScreen({super.key});

  @override
  ConsumerState<MarkStudentAttendanceScreen> createState() => _MarkStudentAttendanceScreenState();
}

class _MarkStudentAttendanceScreenState extends ConsumerState<MarkStudentAttendanceScreen> {
  String? _batchId;
  DateTime _date = DateTime.now();
  final Map<String, AttendanceStatus> _statuses = {};
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _prefilledFor;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _prefillIfNeeded(String batchId, List<String> studentUids, StudentAttendanceRecord? existing) {
    final key = '${batchId}_${dateKey(_date)}';
    if (_prefilledFor == key) return;
    _prefilledFor = key;
    _statuses.clear();
    for (final uid in studentUids) {
      _statuses[uid] = existing?.records[uid] ?? AttendanceStatus.present;
    }
  }

  Future<void> _submit(String batchId) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(attendanceControllerProvider)
          .markStudentAttendance(batchId: batchId, date: _date, records: Map.of(_statuses));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    } on AttendanceFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student attendance')),
      body: SafeArea(
        child: batchesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load batches.\n$error'),
          data: (batches) {
            if (batches.isEmpty) return const EmptyView(message: 'No active batches yet.');
            _batchId ??= batches.first.batchId;
            final batchId = _batchId!;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: batchId,
                          decoration: const InputDecoration(labelText: 'Batch'),
                          items: batches
                              .map((b) => DropdownMenuItem(value: b.batchId, child: Text(b.name)))
                              .toList(),
                          onChanged: _isSubmitting ? null : (value) => setState(() => _batchId = value),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: _isSubmitting ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(dateKey(_date)),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final studentsAsync = ref.watch(allStudentsProvider);
                      final existingAsync = ref.watch(batchAttendanceProvider(batchId));
                      return studentsAsync.when(
                        loading: () => const LoadingView(),
                        error: (error, stackTrace) => ErrorView(message: 'Could not load students.\n$error'),
                        data: (allStudents) {
                          final students = allStudents.where((s) => s.batchId == batchId && s.active).toList();
                          if (students.isEmpty) {
                            return const EmptyView(message: 'No students in this batch.');
                          }
                          final existing = existingAsync.valueOrNull?.where((r) => r.dateKey == dateKey(_date)).firstOrNull;
                          _prefillIfNeeded(batchId, students.map((s) => s.uid).toList(), existing);

                          return ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: students.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final status = _statuses[student.uid] ?? AttendanceStatus.present;
                              return Card(
                                child: ListTile(
                                  title: Text('${student.name} (${student.accountId})'),
                                  trailing: ToggleButtons(
                                    isSelected: [status == AttendanceStatus.present, status == AttendanceStatus.absent],
                                    onPressed: _isSubmitting
                                        ? null
                                        : (i) => setState(
                                            () => _statuses[student.uid] = i == 0
                                                ? AttendanceStatus.present
                                                : AttendanceStatus.absent,
                                          ),
                                    children: const [
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('P')),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('A')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(label: 'Save attendance', isLoading: _isSubmitting, onPressed: () => _submit(batchId)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
