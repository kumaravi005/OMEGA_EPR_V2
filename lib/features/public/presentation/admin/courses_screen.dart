import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../application/public_content_controller.dart';
import '../../data/course.dart';
import '../../data/public_content_repositories.dart';

/// Admin management for the public homepage's "Our courses" row.
/// Ordered by [Course.sortOrder] - drag to reorder here, which the public
/// page then reads directly (see `PublicHomeScreen`'s `_CoursesSection`).
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(allCoursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Our courses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseForm(
          context,
          nextSortOrder: coursesAsync.valueOrNull?.length ?? 0,
        ),
        icon: const Icon(Icons.add),
        label: const Text('New course'),
      ),
      body: SafeArea(
        child: coursesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load courses.\n$error'),
          data: (courses) {
            if (courses.isEmpty) {
              return const EmptyView(message: 'No courses yet.');
            }
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Text(
                    'Shown as a scrollable row on the public site. '
                    'Drag to reorder - the first course shows first.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: courses.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      final reordered = courses.toList();
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(publicContentControllerProvider)
                            .reorderCourses(reordered);
                      } on PublicContentFailure catch (failure) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _CourseTile(
                        key: ValueKey(course.courseId),
                        course: course,
                      );
                    },
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

class _CourseTile extends ConsumerWidget {
  const _CourseTile({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.08),
          backgroundImage:
              (course.imageUrl != null && course.imageUrl!.isNotEmpty)
              ? NetworkImage(course.imageUrl!)
              : null,
          child: (course.imageUrl == null || course.imageUrl!.isEmpty)
              ? Icon(
                  Icons.school_outlined,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
        title: Text(course.title),
        subtitle: Text(course.description ?? 'No description'),
        onTap: () => _showCourseForm(
          context,
          existing: course,
          nextSortOrder: course.sortOrder,
        ),
        trailing: Switch(
          value: course.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(publicContentControllerProvider)
                  .setCourseActive(course, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showCourseForm(
  BuildContext context, {
  Course? existing,
  required int nextSortOrder,
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _CourseFormDialog(existing: existing, nextSortOrder: nextSortOrder),
  );
}

class _CourseFormDialog extends ConsumerStatefulWidget {
  const _CourseFormDialog({this.existing, required this.nextSortOrder});

  final Course? existing;
  final int nextSortOrder;

  @override
  ConsumerState<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends ConsumerState<_CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _imageUrlController = TextEditingController(
    text: widget.existing?.imageUrl ?? '',
  );
  late final _trackTagController = TextEditingController(
    text: widget.existing?.trackTag ?? '',
  );
  late final _subjectChipsController = TextEditingController(
    text: widget.existing?.subjectChips.join(', ') ?? '',
  );
  late final _syllabusUrlController = TextEditingController(
    text: widget.existing?.syllabusUrl ?? '',
  );
  late bool _active = widget.existing?.active ?? true;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _trackTagController.dispose();
    _subjectChipsController.dispose();
    _syllabusUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(publicContentControllerProvider)
          .saveCourse(
            existing: widget.existing,
            title: _titleController.text,
            description: _descriptionController.text,
            imageUrl: _imageUrlController.text,
            trackTag: _trackTagController.text,
            subjectChips: _subjectChipsController.text.split(','),
            syllabusUrl: _syllabusUrlController.text,
            active: _active,
            sortOrder: widget.nextSortOrder,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PublicContentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New course' : 'Edit course'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppTextField(
                controller: _titleController,
                label: 'Title',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Title is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _descriptionController,
                label: 'Description (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _imageUrlController,
                label: 'Icon/image URL (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _trackTagController,
                label: 'Track tag (optional)',
                hintText: 'e.g. Foundation, Competitive',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _subjectChipsController,
                label: 'Subject chips (optional)',
                hintText: 'Comma-separated, e.g. Science, Maths',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _syllabusUrlController,
                label: 'Syllabus link (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
