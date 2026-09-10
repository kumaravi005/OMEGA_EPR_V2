import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';

/// A teacher's own attendance history - view only (marking is admin-only;
/// see firestore.rules).
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
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: records.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return Card(
                            child: ListTile(
                              title: Text(record.dateKey),
                              trailing: Text(
                                record.status.label,
                                style: TextStyle(
                                  color:
                                      record.status == AttendanceStatus.present
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }
}
