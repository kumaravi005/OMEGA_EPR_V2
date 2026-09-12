import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academic_session.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/board.dart';
import '../../academics/data/school_class.dart';
import '../application/batch_controller.dart';
import '../data/batch.dart';
import '../data/batch_repository.dart';
import 'batch_form_dialog.dart';

enum _StatusFilter { all, active, inactive }

/// Admin's batch list - search by name/code, filter by academic session/
/// class/status. All filtering happens client-side on the one
/// `allBatchesProvider` stream (see that provider's doc comment for why
/// that's the safe, zero-index approach at this project's scale).
class BatchListScreen extends ConsumerStatefulWidget {
  const BatchListScreen({super.key});

  @override
  ConsumerState<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends ConsumerState<BatchListScreen> {
  final _searchController = TextEditingController();
  String? _sessionFilter;
  String? _classFilter;
  _StatusFilter _statusFilter = _StatusFilter.active;

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

  bool _matches(Batch batch) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        batch.name.toLowerCase().contains(query) ||
        (batch.batchCode?.toLowerCase().contains(query) ?? false);
    final matchesSession =
        _sessionFilter == null || batch.academicSessionId == _sessionFilter;
    final matchesClass = _classFilter == null || batch.classId == _classFilter;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.active => batch.active,
      _StatusFilter.inactive => !batch.active,
    };
    return matchesQuery && matchesSession && matchesClass && matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(allBatchesProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final boardsAsync = ref.watch(allBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Batches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBatchFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New batch'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by name or code',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: sessionsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (sessions) => DropdownButtonFormField<String?>(
                            initialValue: _sessionFilter,
                            decoration: const InputDecoration(
                              labelText: 'Session (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All sessions'),
                              ),
                              for (final session in sessions)
                                DropdownMenuItem<String?>(
                                  value: session.sessionId,
                                  child: Text(session.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _sessionFilter = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: classesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (classes) => DropdownButtonFormField<String?>(
                            initialValue: _classFilter,
                            decoration: const InputDecoration(
                              labelText: 'Class (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All classes'),
                              ),
                              for (final schoolClass in classes)
                                DropdownMenuItem<String?>(
                                  value: schoolClass.classId,
                                  child: Text(schoolClass.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _classFilter = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<_StatusFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _StatusFilter.active,
                        label: Text('Active'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.inactive,
                        label: Text('Inactive'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.all,
                        label: Text('All'),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _statusFilter = selection.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: batchesAsync.when(
                loading: () => const LoadingView(message: 'Loading batches...'),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load batches.\n$error'),
                data: (batches) {
                  final filtered = batches.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No batches match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _BatchTile(
                      batch: filtered[index],
                      sessions: sessionsAsync.valueOrNull ?? const [],
                      classes: classesAsync.valueOrNull ?? const [],
                      boards: boardsAsync.valueOrNull ?? const [],
                    ),
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

class _BatchTile extends ConsumerWidget {
  const _BatchTile({
    required this.batch,
    required this.sessions,
    required this.classes,
    required this.boards,
  });

  final Batch batch;
  final List<AcademicSession> sessions;
  final List<SchoolClass> classes;
  final List<Board> boards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionName = sessions
        .where((s) => s.sessionId == batch.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == batch.classId)
        .firstOrNull
        ?.name;
    final boardName = batch.boardId == null
        ? null
        : boards.where((b) => b.boardId == batch.boardId).firstOrNull?.name;
    final resolvedBoardName =
        boardName == 'Others' && (batch.boardCustomText?.isNotEmpty ?? false)
        ? batch.boardCustomText
        : boardName;

    final subtitleParts = <String>[
      if (className != null)
        className
      else if (!batch.isLinkedToMasterData)
        'No class set',
      ?resolvedBoardName,
      if (sessionName != null)
        sessionName
      else if (!batch.isLinkedToMasterData)
        'No session set',
      'Students: ${batch.studentCount}',
    ];

    return Card(
      child: ListTile(
        title: Text(
          batch.batchCode == null
              ? batch.name
              : '${batch.name} (${batch.batchCode})',
        ),
        subtitle: Text(
          '${subtitleParts.join(' - ')}\n'
          'Monthly: Rs. ${batch.standardMonthlyFee.toStringAsFixed(0)}   '
          'Installment: Rs. ${batch.standardInstallmentFee.toStringAsFixed(0)}'
          '${batch.active ? '' : '   (inactive)'}',
        ),
        isThreeLine: true,
        onTap: () => showBatchFormDialog(context, existing: batch),
        trailing: PopupMenuButton<bool>(
          onSelected: (active) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(batchControllerProvider).setActive(batch, active);
            } on BatchFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: !batch.active,
              child: Text(batch.active ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }
}
