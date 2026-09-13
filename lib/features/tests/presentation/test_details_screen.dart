import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_repository.dart';
import '../application/test_controller.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';

/// Test Information / Academic Information / Marks Information, plus
/// access to Enter/View Marks - the "Test Details" screen the Set 14
/// spec asks for, kept separate from the marks-entry grid itself.
class TestDetailsScreen extends ConsumerWidget {
  const TestDetailsScreen({
    super.key,
    required this.testId,
    required this.basePath,
  });

  final String testId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testByIdProvider(testId));

    return Scaffold(
      appBar: AppBar(title: const Text('Test details')),
      body: SafeArea(
        child: testAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load the test.\n$error'),
          data: (test) {
            if (test == null) {
              return const ErrorView(message: 'Test not found.');
            }
            return _DetailsBody(test: test, basePath: basePath);
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.test, required this.basePath});

  final TestDefinition test;
  final String basePath;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(testControllerProvider).setActive(test, !test.active);
    } on TestActionFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(testControllerProvider).publishResult(test);
      messenger.showSnackBar(const SnackBar(content: Text('Result published.')));
    } on TestActionFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        ref.watch(currentUserAccountProvider).valueOrNull?.role ==
        UserRole.admin;
    final sessions = ref.watch(allAcademicSessionsProvider).valueOrNull ?? [];
    final classes = ref.watch(allSchoolClassesProvider).valueOrNull ?? [];
    final batches = ref.watch(allBatchesProvider).valueOrNull ?? [];
    final students = ref.watch(allStudentsProvider).valueOrNull ?? [];
    final resultsAsync = ref.watch(testResultsForTestProvider(test.testId));

    final sessionName = sessions
        .where((s) => s.sessionId == test.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == test.classId)
        .firstOrNull
        ?.name;
    final batchName = batches
        .where((b) => b.batchId == test.batchId)
        .firstOrNull
        ?.name;
    final eligibleCount = students
        .where((s) => s.batchId == test.batchId && s.active)
        .length;
    final enteredCount = resultsAsync.valueOrNull?.length ?? 0;
    final pending = (eligibleCount - enteredCount).clamp(0, eligibleCount);

    final typeLabel = test.testType == TestType.other
        ? (test.otherTestTypeLabel?.isNotEmpty ?? false
              ? test.otherTestTypeLabel!
              : test.testType.label)
        : test.testType.label;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    test.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(
                  label: Text(test.resultPublished ? 'Published' : 'Draft'),
                ),
              ],
            ),
            if (!test.active)
              Text(
                'Inactive',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Type', value: typeLabel),
                  _InfoRow(label: 'Date', value: dateKey(test.date)),
                  _InfoRow(label: 'Chapter / topic', value: test.chapterTopic),
                  if (test.description != null && test.description!.isNotEmpty)
                    _InfoRow(label: 'Description', value: test.description!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Session', value: sessionName ?? '-'),
                  _InfoRow(label: 'Class', value: className ?? '-'),
                  _InfoRow(label: 'Batch', value: batchName ?? '-'),
                  _InfoRow(label: 'Subject', value: test.subject),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marks information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Maximum marks',
                    value: test.totalMarks.toStringAsFixed(0),
                  ),
                  _InfoRow(label: 'Students', value: '$eligibleCount'),
                  _InfoRow(label: 'Marks entered', value: '$enteredCount'),
                  _InfoRow(label: 'Pending', value: '$pending'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: isAdmin ? 'Enter marks' : 'View marks',
              onPressed: () => context.push('$basePath/${test.testId}/marks'),
            ),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              if (!test.resultPublished)
                AppButton(
                  label: 'Publish result',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _publish(context, ref),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: test.active ? 'Deactivate test' : 'Activate test',
                variant: AppButtonVariant.secondary,
                onPressed: () => _toggleActive(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
