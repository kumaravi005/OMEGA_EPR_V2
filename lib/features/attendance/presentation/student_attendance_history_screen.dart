import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../student/data/student_repository.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_stats.dart';
import '../data/student_attendance_record.dart';

/// A student/parent's own attendance history, present/absent counts and
/// percentage - computed from their batch's attendance records, filtered
/// to just their own uid.
class StudentAttendanceHistoryScreen extends ConsumerWidget {
  const StudentAttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('My attendance')),
      body: SafeArea(
        child: account == null
            ? const LoadingView()
            : Consumer(
                builder: (context, ref, _) {
                  final selfAsync = ref.watch(
                    ownStudentProfileProvider(account.uid),
                  );
                  return selfAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) => ErrorView(
                      message: 'Could not load your profile.\n$error',
                    ),
                    data: (self) {
                      if (self == null) {
                        return const ErrorView(
                          message: 'Student profile not found.',
                        );
                      }
                      return _History(
                        studentUid: self.uid,
                        batchId: self.batchId,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.studentUid, required this.batchId});

  final String studentUid;
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(batchAttendanceProvider(batchId));

    return recordsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load attendance.\n$error'),
      data: (records) {
        final mine = records
            .where((r) => r.records.containsKey(studentUid))
            .toList();
        if (mine.isEmpty) {
          return const EmptyView(message: 'No attendance recorded yet.');
        }

        final stats = computeAttendanceStats(
          mine.map((r) => r.records[studentUid]!),
        );

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Present', value: '${stats.present}'),
                  _Stat(label: 'Absent', value: '${stats.absent}'),
                  _Stat(
                    label: 'Attendance %',
                    value: stats.percentage == null
                        ? '-'
                        : '${stats.percentage!.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final record in mine)
              Card(
                child: ListTile(
                  title: Text(record.dateKey),
                  trailing: Text(
                    record.records[studentUid]!.label,
                    style: TextStyle(
                      color:
                          record.records[studentUid] == AttendanceStatus.present
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
