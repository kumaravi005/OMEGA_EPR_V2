import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../student/data/student_repository.dart';
import '../data/test_repository.dart';

/// A student/parent's own test results, for their batch. Unpublished
/// tests show as "not published yet" - the actual mark is never fetched
/// for those (see firestore.rules: a student can only `get` their own
/// testResults doc once the parent test is published).
class StudentResultsScreen extends ConsumerWidget {
  const StudentResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('My results')),
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
                      return _Results(
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

class _Results extends ConsumerWidget {
  const _Results({required this.studentUid, required this.batchId});

  final String studentUid;
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(batchTestsProvider(batchId));

    return testsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load tests.\n$error'),
      data: (tests) {
        if (tests.isEmpty) return const EmptyView(message: 'No tests yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: tests.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final test = tests[index];
            return Card(
              child: ListTile(
                title: Text('${test.title} (${test.subject})'),
                subtitle: Text('${test.chapterTopic} - ${dateKey(test.date)}'),
                trailing: !test.resultPublished
                    ? const Chip(label: Text('Not published'))
                    : Consumer(
                        builder: (context, ref, _) {
                          final resultAsync = ref.watch(
                            ownTestResultProvider((
                              testId: test.testId,
                              studentUid: studentUid,
                            )),
                          );
                          return resultAsync.when(
                            loading: () => const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (error, stackTrace) =>
                                const Icon(Icons.error_outline),
                            data: (result) {
                              if (result == null) {
                                return const Chip(label: Text('Not entered'));
                              }
                              return Chip(
                                label: Text(
                                  '${result.obtainedMarks.toStringAsFixed(0)}/${result.totalMarks.toStringAsFixed(0)} '
                                  '(${result.percentage.toStringAsFixed(1)}%)',
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
