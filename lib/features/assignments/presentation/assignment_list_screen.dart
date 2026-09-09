import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../batches/data/batch_repository.dart';
import '../application/assignment_controller.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';
import 'create_assignment_dialog.dart';

/// Assignments for a batch. Teachers see every batch (with a picker), can
/// create assignments and close them. Students only ever see their own
/// (fixed) batch, read-only.
class AssignmentListScreen extends ConsumerStatefulWidget {
  const AssignmentListScreen({super.key, this.fixedBatchId});

  final String? fixedBatchId;

  @override
  ConsumerState<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends ConsumerState<AssignmentListScreen> {
  String? _batchId;

  bool get _isTeacherView => widget.fixedBatchId == null;

  @override
  Widget build(BuildContext context) {
    final batchId = widget.fixedBatchId;

    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      floatingActionButton: _isTeacherView && _batchId != null
          ? FloatingActionButton.extended(
              onPressed: () => showCreateAssignmentDialog(context, batchId: _batchId!),
              icon: const Icon(Icons.add),
              label: const Text('New assignment'),
            )
          : null,
      body: SafeArea(
        child: batchId != null
            ? _AssignmentsForBatch(batchId: batchId, isTeacherView: false)
            : Consumer(
                builder: (context, ref, _) {
                  final batchesAsync = ref.watch(activeBatchesProvider);
                  return batchesAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) => ErrorView(message: 'Could not load batches.\n$error'),
                    data: (batches) {
                      if (batches.isEmpty) return const EmptyView(message: 'No active batches yet.');
                      _batchId ??= batches.first.batchId;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: DropdownButtonFormField<String>(
                              initialValue: _batchId,
                              decoration: const InputDecoration(labelText: 'Batch'),
                              items: batches
                                  .map((b) => DropdownMenuItem(value: b.batchId, child: Text(b.name)))
                                  .toList(),
                              onChanged: (value) => setState(() => _batchId = value),
                            ),
                          ),
                          Expanded(child: _AssignmentsForBatch(batchId: _batchId!, isTeacherView: true)),
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

class _AssignmentsForBatch extends ConsumerWidget {
  const _AssignmentsForBatch({required this.batchId, required this.isTeacherView});

  final String batchId;
  final bool isTeacherView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(batchAssignmentsProvider(batchId));

    return assignmentsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) => ErrorView(message: 'Could not load assignments.\n$error'),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No assignments yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _AssignmentTile(assignment: items[index], isTeacherView: isTeacherView),
        );
      },
    );
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.assignment, required this.isTeacherView});

  final Assignment assignment;
  final bool isTeacherView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text('${assignment.title} (${assignment.subject})'),
        subtitle: Text(
          '${assignment.description}\nDue ${dateKey(assignment.dueDate)}'
          '${assignment.teacherRemark != null && assignment.teacherRemark!.isNotEmpty ? '\nRemark: ${assignment.teacherRemark}' : ''}',
        ),
        isThreeLine: true,
        trailing: isTeacherView
            ? PopupMenuButton<AssignmentStatus>(
                onSelected: (status) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(assignmentControllerProvider)
                        .setStatus(assignment, status: status, teacherRemark: assignment.teacherRemark);
                  } on AssignmentFailure catch (failure) {
                    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: AssignmentStatus.active, child: Text('Mark active')),
                  PopupMenuItem(value: AssignmentStatus.closed, child: Text('Mark closed')),
                ],
                child: Chip(label: Text(assignment.status.label)),
              )
            : Chip(label: Text(assignment.status.label)),
      ),
    );
  }
}
