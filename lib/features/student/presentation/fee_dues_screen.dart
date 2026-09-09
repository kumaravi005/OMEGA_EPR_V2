import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../batches/data/batch_repository.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

class FeeDuesScreen extends ConsumerStatefulWidget {
  const FeeDuesScreen({super.key});

  @override
  ConsumerState<FeeDuesScreen> createState() => _FeeDuesScreenState();
}

class _FeeDuesScreenState extends ConsumerState<FeeDuesScreen> {
  final _sessionController = TextEditingController();
  final _classController = TextEditingController();
  final _boardController = TextEditingController();
  final _studentController = TextEditingController();
  String? _batchId;

  @override
  void initState() {
    super.initState();
    for (final c in [_sessionController, _classController, _boardController, _studentController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _classController.dispose();
    _boardController.dispose();
    _studentController.dispose();
    super.dispose();
  }

  bool _matches(StudentProfile student) {
    bool contains(String value, String query) => query.isEmpty || value.toLowerCase().contains(query.toLowerCase());

    return contains(student.academicSession, _sessionController.text) &&
        contains(student.className, _classController.text) &&
        contains(student.board, _boardController.text) &&
        (_batchId == null || student.batchId == _batchId) &&
        (contains(student.name, _studentController.text) || contains(student.accountId, _studentController.text));
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final batchesAsync = ref.watch(allBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fee dues')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: AppTextField(controller: _sessionController, label: 'Session')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppTextField(controller: _classController, label: 'Class')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: AppTextField(controller: _boardController, label: 'Board')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppTextField(controller: _studentController, label: 'Student name/ID')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  batchesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (batches) => DropdownButtonFormField<String?>(
                      initialValue: _batchId,
                      decoration: const InputDecoration(labelText: 'Batch (all)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All batches')),
                        for (final batch in batches)
                          DropdownMenuItem<String?>(value: batch.batchId, child: Text(batch.name)),
                      ],
                      onChanged: (value) => setState(() => _batchId = value),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: studentsAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) => ErrorView(message: 'Could not load students.\n$error'),
                data: (students) {
                  final filtered = students.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(message: 'No students match these filters.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _DueRow(student: filtered[index]),
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

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(studentPaymentsProvider(student.uid));

    return Card(
      child: ListTile(
        title: Text('${student.name} (${student.accountId})'),
        subtitle: Text('${student.className} - ${student.board} - ${student.academicSession}'),
        trailing: paymentsAsync.when(
          loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (error, stackTrace) => const Icon(Icons.error_outline),
          data: (payments) {
            final paid = totalPaid(payments);
            final remaining = due(student, payments);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Paid ₹${paid.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  dueLabel(remaining),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: remaining > 0 ? Theme.of(context).colorScheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
        onTap: () => context.push('${AppRoutes.adminStudents}/${student.uid}'),
      ),
    );
  }
}
