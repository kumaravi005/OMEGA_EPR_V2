import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../data/fee_calculator.dart';
import '../data/fee_summary.dart';

enum _StatusFilter { all, paid, partiallyPaid, due, overdue }

/// Admin → Fees (Set 19 section 17): search + class/batch/session/board/
/// status filters over [allStudentFeeSummariesProvider], all client-side
/// at this project's scale, matching every other admin list screen's
/// established pattern.
class FeeManagementScreen extends ConsumerStatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  ConsumerState<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends ConsumerState<FeeManagementScreen> {
  final _searchController = TextEditingController();
  String? _classId;
  String? _batchId;
  String? _sessionId;
  String? _boardId;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(StudentFeeSummary row) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      final matchesName = row.student.name.toLowerCase().contains(search);
      final matchesId = row.student.accountId.toLowerCase().contains(search);
      if (!matchesName && !matchesId) return false;
    }
    if (_classId != null && row.student.classId != _classId) return false;
    if (_batchId != null && row.student.batchId != _batchId) return false;
    if (_sessionId != null && row.student.academicSessionId != _sessionId) return false;
    if (_boardId != null && row.student.boardId != _boardId) return false;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.paid => row.status == FeeStatus.paid,
      _StatusFilter.partiallyPaid => row.status == FeeStatus.partiallyPaid,
      _StatusFilter.due => row.status == FeeStatus.due,
      _StatusFilter.overdue => row.status == FeeStatus.overdue,
    };
    return matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(allStudentFeeSummariesProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final boardsAsync = ref.watch(activeBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by student name or ID',
                    suffixIcon: const Icon(Icons.search),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DropdownButton<String?>(
                          value: _sessionId,
                          hint: const Text('Session'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All sessions')),
                            for (final session in sessionsAsync.valueOrNull ?? const [])
                              DropdownMenuItem(value: session.sessionId, child: Text(session.name)),
                          ],
                          onChanged: (value) => setState(() => _sessionId = value),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String?>(
                          value: _classId,
                          hint: const Text('Class'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All classes')),
                            for (final schoolClass in classesAsync.valueOrNull ?? const [])
                              DropdownMenuItem(value: schoolClass.classId, child: Text(schoolClass.name)),
                          ],
                          onChanged: (value) => setState(() => _classId = value),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String?>(
                          value: _batchId,
                          hint: const Text('Batch'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All batches')),
                            for (final batch in batchesAsync.valueOrNull ?? const [])
                              DropdownMenuItem(value: batch.batchId, child: Text(batch.name)),
                          ],
                          onChanged: (value) => setState(() => _batchId = value),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String?>(
                          value: _boardId,
                          hint: const Text('Board'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All boards')),
                            for (final board in boardsAsync.valueOrNull ?? const [])
                              DropdownMenuItem(value: board.boardId, child: Text(board.name)),
                          ],
                          onChanged: (value) => setState(() => _boardId = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_StatusFilter>(
                      segments: const [
                        ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                        ButtonSegment(value: _StatusFilter.paid, label: Text('Paid')),
                        ButtonSegment(value: _StatusFilter.partiallyPaid, label: Text('Partial')),
                        ButtonSegment(value: _StatusFilter.due, label: Text('Due')),
                        ButtonSegment(value: _StatusFilter.overdue, label: Text('Overdue')),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (selection) =>
                          setState(() => _statusFilter = selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: summariesAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load fee summaries.\n$error'),
                data: (rows) {
                  final filtered = rows.where(_matches).toList()
                    ..sort((a, b) => a.student.name.compareTo(b.student.name));
                  if (filtered.isEmpty) {
                    return const EmptyView(message: 'No students match these filters.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _FeeRow(row: filtered[index]),
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

class _FeeRow extends ConsumerWidget {
  const _FeeRow({required this.row});

  final StudentFeeSummary row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = row.admission;
    final batches = ref.watch(allBatchesProvider).valueOrNull ?? const [];
    final batchName = batches.where((b) => b.batchId == row.student.batchId).firstOrNull?.name;
    final subtitleParts = <String>[
      row.student.className,
      ?batchName,
      if (admission != null) 'Final fee ₹${admission.finalFee.toStringAsFixed(0)}',
    ];
    return Card(
      child: ListTile(
        title: Text('${row.student.name} (${row.student.accountId})'),
        subtitle: Text(subtitleParts.join(' - ')),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Paid ₹${row.totalPaid.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              row.status == null
                  ? 'No admission'
                  : row.balanceDue > 0
                      ? 'Due ₹${row.balanceDue.toStringAsFixed(0)}'
                      : 'Paid in full',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: row.status == FeeStatus.overdue
                    ? Theme.of(context).colorScheme.error
                    : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (row.status != null) Chip(label: Text(row.status!.label)),
          ],
        ),
        onTap: () => context.push('${AppRoutes.adminFeeDues}/${row.student.uid}'),
      ),
    );
  }
}
