import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../teacher/data/teacher_repository.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';

/// Admin marks each teacher's attendance for a chosen date.
class MarkTeacherAttendanceScreen extends ConsumerStatefulWidget {
  const MarkTeacherAttendanceScreen({super.key});

  @override
  ConsumerState<MarkTeacherAttendanceScreen> createState() =>
      _MarkTeacherAttendanceScreenState();
}

class _MarkTeacherAttendanceScreenState
    extends ConsumerState<MarkTeacherAttendanceScreen> {
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(allTeachersProvider);

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
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(dateKey(_date)),
                ),
              ),
            ),
            Expanded(
              child: teachersAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load teachers.\n$error'),
                data: (teachers) {
                  if (teachers.isEmpty) {
                    return const EmptyView(message: 'No teachers yet.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: teachers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      return _TeacherAttendanceTile(
                        teacherUid: teacher.uid,
                        teacherName: teacher.name,
                        date: _date,
                      );
                    },
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

class _TeacherAttendanceTile extends ConsumerWidget {
  const _TeacherAttendanceTile({
    required this.teacherUid,
    required this.teacherName,
    required this.date,
  });

  final String teacherUid;
  final String teacherName;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(teacherOwnAttendanceProvider(teacherUid));
    final existing = historyAsync.valueOrNull
        ?.where((r) => r.dateKey == dateKey(date))
        .firstOrNull;
    final status = existing?.status;

    return Card(
      child: ListTile(
        title: Text(teacherName),
        trailing: ToggleButtons(
          isSelected: [
            status == AttendanceStatus.present,
            status == AttendanceStatus.absent,
          ],
          onPressed: (i) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(attendanceControllerProvider)
                  .markTeacherAttendance(
                    teacherUid: teacherUid,
                    date: date,
                    status: i == 0
                        ? AttendanceStatus.present
                        : AttendanceStatus.absent,
                  );
            } on AttendanceFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
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
