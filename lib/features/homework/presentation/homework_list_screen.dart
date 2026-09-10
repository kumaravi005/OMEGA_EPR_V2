import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../batches/data/batch_repository.dart';
import '../application/homework_controller.dart';
import '../data/homework.dart';
import '../data/homework_repository.dart';
import 'create_homework_dialog.dart';

/// Homework for a batch. Teachers see every batch (with a picker), can
/// create homework and mark completion. Students only ever see their own
/// (fixed) batch, read-only.
class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key, this.fixedBatchId});

  /// When set (a student's own batch), the batch picker/create action are
  /// hidden and only this batch's homework is shown.
  final String? fixedBatchId;

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> {
  String? _batchId;

  bool get _isTeacherView => widget.fixedBatchId == null;

  @override
  Widget build(BuildContext context) {
    final batchId = widget.fixedBatchId;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      floatingActionButton: _isTeacherView && _batchId != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showCreateHomeworkDialog(context, batchId: _batchId!),
              icon: const Icon(Icons.add),
              label: const Text('New homework'),
            )
          : null,
      body: SafeArea(
        child: batchId != null
            ? _HomeworkForBatch(batchId: batchId, isTeacherView: false)
            : Consumer(
                builder: (context, ref, _) {
                  final batchesAsync = ref.watch(activeBatchesProvider);
                  return batchesAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) =>
                        ErrorView(message: 'Could not load batches.\n$error'),
                    data: (batches) {
                      if (batches.isEmpty) {
                        return const EmptyView(
                          message: 'No active batches yet.',
                        );
                      }
                      _batchId ??= batches.first.batchId;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: DropdownButtonFormField<String>(
                              initialValue: _batchId,
                              decoration: const InputDecoration(
                                labelText: 'Batch',
                              ),
                              items: batches
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b.batchId,
                                      child: Text(b.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _batchId = value),
                            ),
                          ),
                          Expanded(
                            child: _HomeworkForBatch(
                              batchId: _batchId!,
                              isTeacherView: true,
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

class _HomeworkForBatch extends ConsumerWidget {
  const _HomeworkForBatch({required this.batchId, required this.isTeacherView});

  final String batchId;
  final bool isTeacherView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworkAsync = ref.watch(batchHomeworkProvider(batchId));

    return homeworkAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load homework.\n$error'),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No homework yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _HomeworkTile(
            homework: items[index],
            isTeacherView: isTeacherView,
          ),
        );
      },
    );
  }
}

class _HomeworkTile extends ConsumerWidget {
  const _HomeworkTile({required this.homework, required this.isTeacherView});

  final Homework homework;
  final bool isTeacherView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(homework.subject),
        subtitle: Text(
          '${homework.description}\nDue ${dateKey(homework.dueDate)}',
        ),
        isThreeLine: true,
        trailing: isTeacherView
            ? PopupMenuButton<CompletionStatus>(
                onSelected: (status) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(homeworkControllerProvider)
                        .setCompletion(
                          homework,
                          status: status,
                          remark: homework.remark,
                        );
                  } on HomeworkFailure catch (failure) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(failure.message)),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: CompletionStatus.pending,
                    child: Text('Mark pending'),
                  ),
                  PopupMenuItem(
                    value: CompletionStatus.completed,
                    child: Text('Mark completed'),
                  ),
                ],
                child: Chip(label: Text(homework.completionStatus.label)),
              )
            : Chip(label: Text(homework.completionStatus.label)),
      ),
    );
  }
}
