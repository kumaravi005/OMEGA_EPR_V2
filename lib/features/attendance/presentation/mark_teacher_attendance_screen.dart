import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../teacher/data/teacher_profile.dart';
import '../../teacher/data/teacher_repository.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';
import '../data/teacher_attendance_record.dart';

/// Admin marks every teacher's attendance for a chosen date, staged
/// locally and saved together in one efficient write (Set 13 spec) -
/// mirroring [MarkStudentAttendanceScreen]'s date-then-list-then-save
/// flow rather than writing on every tap.
class MarkTeacherAttendanceScreen extends ConsumerStatefulWidget {
  const MarkTeacherAttendanceScreen({super.key});

  @override
  ConsumerState<MarkTeacherAttendanceScreen> createState() =>
      _MarkTeacherAttendanceScreenState();
}

class _MarkTeacherAttendanceScreenState
    extends ConsumerState<MarkTeacherAttendanceScreen> {
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

  void _prefillIfNeeded(
    List<String> teacherUids,
    List<TeacherAttendanceRecord> allRecords,
  ) {
    final key = dateKey(_date);
    if (_prefilledFor == key) return;
    _prefilledFor = key;
    _statuses.clear();
    for (final uid in teacherUids) {
      final existing = allRecords
          .where((r) => r.teacherUid == uid && r.dateKey == key)
          .firstOrNull;
      _statuses[uid] = existing?.status ?? AttendanceStatus.present;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(attendanceControllerProvider)
          .markTeacherAttendanceBulk(date: _date, statuses: Map.of(_statuses));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    } on AttendanceFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(allTeachersProvider);
    final attendanceAsync = ref.watch(allTeacherAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher attendance')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSubmitting ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(dateKey(_date)),
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: teachersAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load teachers.\n$error'),
                data: (allTeachers) {
                  final key = dateKey(_date);
                  final allRecords = attendanceAsync.valueOrNull ?? const [];

                  // Active teachers, plus any teacher already recorded for
                  // this date even if since deactivated - editing a past
                  // date must never silently drop them from view.
                  final activeTeachers = allTeachers
                      .where((t) => t.active)
                      .toList();
                  final historicalExtras = allTeachers
                      .where(
                        (t) =>
                            !t.active &&
                            allRecords.any(
                              (r) =>
                                  r.teacherUid == t.uid && r.dateKey == key,
                            ),
                      )
                      .toList();
                  final teachers = [...activeTeachers, ...historicalExtras];

                  if (teachers.isEmpty) {
                    return const EmptyView(message: 'No active teachers yet.');
                  }

                  _prefillIfNeeded(
                    teachers.map((t) => t.uid).toList(),
                    allRecords,
                  );

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: teachers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      final status =
                          _statuses[teacher.uid] ?? AttendanceStatus.present;
                      return _TeacherAttendanceTile(
                        teacher: teacher,
                        status: status,
                        enabled: !_isSubmitting,
                        onChanged: (value) =>
                            setState(() => _statuses[teacher.uid] = value),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Save attendance',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherAttendanceTile extends StatelessWidget {
  const _TeacherAttendanceTile({
    required this.teacher,
    required this.status,
    required this.enabled,
    required this.onChanged,
  });

  final TeacherProfile teacher;
  final AttendanceStatus status;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(teacher.name),
        subtitle: teacher.active
            ? null
            : const Text(
                'Inactive',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
        trailing: ToggleButtons(
          isSelected: [
            status == AttendanceStatus.present,
            status == AttendanceStatus.absent,
          ],
          onPressed: enabled
              ? (i) => onChanged(
                  i == 0 ? AttendanceStatus.present : AttendanceStatus.absent,
                )
              : null,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('P'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('A'),
            ),
          ],
        ),
      ),
    );
  }
}
