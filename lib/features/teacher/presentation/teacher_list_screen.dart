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
import '../../academics/data/subject.dart';
import '../data/teacher_profile.dart';
import '../data/teacher_repository.dart';

enum _StatusFilter { all, active, inactive }

/// Admin's teacher list - search by name/qualification/mobile, filter by
/// subject and status. All filtering happens client-side on the one
/// `allTeachersProvider` stream, matching `StudentListScreen`/
/// `BatchListScreen`'s established pattern - appropriate at this
/// project's scale (~10 teachers).
class TeacherListScreen extends ConsumerStatefulWidget {
  const TeacherListScreen({super.key});

  @override
  ConsumerState<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends ConsumerState<TeacherListScreen> {
  final _searchController = TextEditingController();
  String? _subjectFilter;
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

  bool _matches(TeacherProfile teacher) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        teacher.name.toLowerCase().contains(query) ||
        teacher.qualification.toLowerCase().contains(query) ||
        teacher.primaryMobile.contains(query);
    final matchesSubject =
        _subjectFilter == null || teacher.subjectIds.contains(_subjectFilter);
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.active => teacher.active,
      _StatusFilter.inactive => !teacher.active,
    };
    return matchesQuery && matchesSubject && matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(allTeachersProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminNewTeacher),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New teacher'),
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
                    label: 'Search by name, qualification or mobile',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  subjectsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (subjects) => DropdownButtonFormField<String?>(
                      initialValue: _subjectFilter,
                      decoration: const InputDecoration(
                        labelText: 'Subject (all)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All subjects'),
                        ),
                        for (final subject in subjects)
                          DropdownMenuItem<String?>(
                            value: subject.subjectId,
                            child: Text(subject.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _subjectFilter = value),
                    ),
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
                      ButtonSegment(value: _StatusFilter.all, label: Text('All')),
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
              child: teachersAsync.when(
                loading: () => const LoadingView(message: 'Loading teachers...'),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load teachers.\n$error'),
                data: (teachers) {
                  final filtered = teachers.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No teachers match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _TeacherTile(
                      teacher: filtered[index],
                      subjects: subjectsAsync.valueOrNull ?? const [],
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

class _TeacherTile extends StatelessWidget {
  const _TeacherTile({required this.teacher, required this.subjects});

  final TeacherProfile teacher;
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    final subjectNames = subjects
        .where((s) => teacher.subjectIds.contains(s.subjectId))
        .map((s) => s.name)
        .join(', ');

    return Card(
      child: ListTile(
        title: Text('${teacher.name} (${teacher.accountId})'),
        subtitle: Text(
          '${teacher.qualification}\n'
          '${teacher.primaryMobile}   '
          '${subjectNames.isEmpty ? 'No subjects assigned yet' : subjectNames}'
          '${teacher.active ? '' : '   (inactive)'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        onTap: () => context.push('${AppRoutes.adminTeachers}/${teacher.uid}'),
      ),
    );
  }
}
