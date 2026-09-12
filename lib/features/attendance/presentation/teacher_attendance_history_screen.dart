import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_stats.dart';
import '../data/student_attendance_record.dart';

/// A teacher's own attendance history, present/absent counts and
/// percentage - view only (marking is admin-only; see firestore.rules).
class TeacherAttendanceHistoryScreen extends ConsumerWidget {
  const TeacherAttendanceHistoryScreen({super.key});

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
                  final recordsAsync = ref.watch(
                    teacherOwnAttendanceProvider(account.uid),
                  );
                  return recordsAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) => ErrorView(
                      message: 'Could not load attendance.\n$error',
                    ),
                    data: (records) {
                      if (records.isEmpty) {
                        return const EmptyView(
                          message: 'No attendance recorded yet.',
                        );
                      }
                      final stats = computeAttendanceStats(
                        records.map((r) => r.status),
                      );
                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          AppCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat(
                                  label: 'Present',
                                  value: '${stats.present}',
                                ),
                                _Stat(
                                  label: 'Absent',
                                  value: '${stats.absent}',
                                ),
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
                          for (final record in records)
                            Card(
                              child: ListTile(
                                title: Text(record.dateKey),
                                trailing: Text(
                                  record.status.label,
                                  style: TextStyle(
                                    color:
                                        record.status ==
                                            AttendanceStatus.present
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
                },
              ),
      ),
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
