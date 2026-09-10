import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../batches/data/batch_repository.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';
import 'create_test_dialog.dart';

/// Teacher/admin test list: pick a batch, create tests, tap one to enter
/// marks and publish results. Reached from both `/admin/tests` and
/// `/teacher/tests` (see lib/router.dart) - [basePath] is whichever of
/// those the caller came from, so "enter marks" navigates correctly
/// either way.
class TestListScreen extends ConsumerStatefulWidget {
  const TestListScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends ConsumerState<TestListScreen> {
  String? _batchId;

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tests')),
      floatingActionButton: _batchId != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showCreateTestDialog(context, batchId: _batchId!),
              icon: const Icon(Icons.add),
              label: const Text('New test'),
            )
          : null,
      body: SafeArea(
        child: batchesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load batches.\n$error'),
          data: (batches) {
            if (batches.isEmpty) {
              return const EmptyView(message: 'No active batches yet.');
            }
            _batchId ??= batches.first.batchId;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    initialValue: _batchId,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: batches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.batchId,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _batchId = value),
                  ),
                ),
                Expanded(
                  child: _TestsForBatch(
                    batchId: _batchId!,
                    basePath: widget.basePath,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TestsForBatch extends ConsumerWidget {
  const _TestsForBatch({required this.batchId, required this.basePath});

  final String batchId;
  final String basePath;

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
          itemBuilder: (context, index) =>
              _TestTile(test: tests[index], basePath: basePath),
        );
      },
    );
  }
}

class _TestTile extends StatelessWidget {
  const _TestTile({required this.test, required this.basePath});

  final TestDefinition test;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${test.title} (${test.subject})'),
        subtitle: Text(
          '${test.chapterTopic} - ${dateKey(test.date)} - ${test.totalMarks.toStringAsFixed(0)} marks',
        ),
        trailing: Chip(
          label: Text(test.resultPublished ? 'Published' : 'Draft'),
        ),
        onTap: () => context.push('$basePath/${test.testId}'),
      ),
    );
  }
}
