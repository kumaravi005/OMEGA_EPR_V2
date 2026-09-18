import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../student/data/student_repository.dart';
import '../data/academic_work.dart';
import '../data/academic_work_repository.dart';
import '../data/work_completion.dart';
import '../data/work_completion_repository.dart';
import 'work_completion_style.dart';

enum _TypeTab { all, homework, assignment }

enum _StatusTab { active, closed }

/// A student/parent's own homework & assignments - published/closed
/// items for their current batch only, never a draft, never another
/// batch's (Set 16 spec). Read-only: opening an item shows full
/// instructions via the shared `AcademicWorkDetailsScreen`.
class StudentAcademicWorkScreen extends ConsumerWidget {
  const StudentAcademicWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework & Assignments')),
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
                      message:
                          'Unable to load your profile. Please try again.\n$error',
                    ),
                    data: (self) {
                      if (self == null) {
                        return const ErrorView(
                          message: 'Student profile not found.',
                        );
                      }
                      return _Body(batchId: self.batchId);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.batchId});

  final String batchId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  _TypeTab _typeTab = _TypeTab.all;
  _StatusTab _statusTab = _StatusTab.active;

  bool _matches(AcademicWork work) {
    final matchesType = switch (_typeTab) {
      _TypeTab.all => true,
      _TypeTab.homework => work.type == AcademicWorkType.homework,
      _TypeTab.assignment => work.type == AcademicWorkType.assignment,
    };
    final matchesStatus = switch (_statusTab) {
      _StatusTab.active => work.status == AcademicWorkStatus.published,
      _StatusTab.closed => work.status == AcademicWorkStatus.closed,
    };
    return matchesType && matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final workAsync = ref.watch(
      studentVisibleAcademicWorkProvider(widget.batchId),
    );
    final completionByWork = {
      for (final completion
          in ref.watch(myWorkCompletionsProvider).valueOrNull ??
              const <WorkCompletion>[])
        completion.workId: completion,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SegmentedButton<_TypeTab>(
                segments: const [
                  ButtonSegment(value: _TypeTab.all, label: Text('All')),
                  ButtonSegment(
                    value: _TypeTab.homework,
                    label: Text('Homework'),
                  ),
                  ButtonSegment(
                    value: _TypeTab.assignment,
                    label: Text('Assignments'),
                  ),
                ],
                selected: {_typeTab},
                onSelectionChanged: (selection) =>
                    setState(() => _typeTab = selection.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<_StatusTab>(
                segments: const [
                  ButtonSegment(
                    value: _StatusTab.active,
                    label: Text('Active'),
                  ),
                  ButtonSegment(
                    value: _StatusTab.closed,
                    label: Text('Completed / Closed'),
                  ),
                ],
                selected: {_statusTab},
                onSelectionChanged: (selection) =>
                    setState(() => _statusTab = selection.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: workAsync.when(
            loading: () => const LoadingView(),
            error: (error, stackTrace) => ErrorView(
              message: 'Unable to load homework. Please try again.\n$error',
            ),
            data: (items) {
              final filtered = items.where(_matches).toList();
              if (filtered.isEmpty) {
                return const EmptyView(
                  message: 'No homework or assignments available.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _WorkTile(
                  work: filtered[index],
                  completion: completionByWork[filtered[index].workId],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work, required this.completion});

  final AcademicWork work;
  final WorkCompletion? completion;

  @override
  Widget build(BuildContext context) {
    final overdue = work.isOverdue(DateTime.now());
    return Card(
      child: ListTile(
        title: Text(work.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${work.type.label} - ${work.subject}\n'
              'Assigned ${dateKey(work.assignedDate)} - Due ${dateKey(work.dueDate)}'
              '${overdue ? ' (Overdue)' : ''}',
            ),
            if (completion != null) ...[
              const SizedBox(height: AppSpacing.xs),
              WorkCompletionChip(status: completion!.status),
            ],
          ],
        ),
        trailing: Chip(label: Text(work.status.label)),
        onTap: () =>
            context.push('${AppRoutes.studentAcademicWork}/${work.workId}'),
      ),
    );
  }
}
