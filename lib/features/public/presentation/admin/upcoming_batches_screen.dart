import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_key.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../application/public_content_controller.dart';
import '../../data/public_content_repositories.dart';
import '../../data/upcoming_batch.dart';

class UpcomingBatchesScreen extends ConsumerWidget {
  const UpcomingBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(allUpcomingBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming batches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: SafeArea(
        child: batchesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load listings.\n$error'),
          data: (batches) {
            if (batches.isEmpty) {
              return const EmptyView(
                message: 'No upcoming batch listings yet.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: batches.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _Tile(batch: batches[index]),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.batch});

  final UpcomingBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text('${batch.title} - ${batch.className}'),
        subtitle: Text(
          'Starts ${dateKey(batch.startDate)} - ${batch.timing}\n${batch.admissionStatus}',
        ),
        isThreeLine: true,
        onTap: () => _showForm(context, existing: batch),
        trailing: Switch(
          value: batch.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(publicContentControllerProvider)
                  .setUpcomingBatchActive(batch, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showForm(BuildContext context, {UpcomingBatch? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _FormDialog(existing: existing),
  );
}

class _FormDialog extends ConsumerStatefulWidget {
  const _FormDialog({this.existing});

  final UpcomingBatch? existing;

  @override
  ConsumerState<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends ConsumerState<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _posterUrlController = TextEditingController(
    text: widget.existing?.posterUrl ?? '',
  );
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _classController = TextEditingController(
    text: widget.existing?.className ?? '',
  );
  late final _boardController = TextEditingController(
    text: widget.existing?.board ?? '',
  );
  late final _sessionController = TextEditingController(
    text: widget.existing?.academicSession ?? '',
  );
  late final _timingController = TextEditingController(
    text: widget.existing?.timing ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _admissionStatusController = TextEditingController(
    text: widget.existing?.admissionStatus ?? 'Admission open',
  );
  late bool _active = widget.existing?.active ?? true;
  DateTime _startDate = DateTime.now();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _posterUrlController.dispose();
    _titleController.dispose();
    _classController.dispose();
    _boardController.dispose();
    _sessionController.dispose();
    _timingController.dispose();
    _descriptionController.dispose();
    _admissionStatusController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(_startDate.year - 1),
      lastDate: DateTime(_startDate.year + 2),
    );
    if (picked != null) setState(() => _startDate = picked);
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
          .saveUpcomingBatch(
            existing: widget.existing,
            posterUrl: _posterUrlController.text,
            title: _titleController.text,
            className: _classController.text,
            board: _boardController.text,
            academicSession: _sessionController.text,
            startDate: _startDate,
            timing: _timingController.text,
            description: _descriptionController.text,
            admissionStatus: _admissionStatusController.text,
            active: _active,
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
      title: Text(
        widget.existing == null ? 'New upcoming batch' : 'Edit upcoming batch',
      ),
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
                controller: _posterUrlController,
                label: 'Poster image URL (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Title is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _classController,
                label: 'Class',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Class is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _boardController,
                label: 'Board',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Board is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _sessionController,
                label: 'Academic session',
                hintText: 'e.g. 2026-27',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(
                  value,
                  message: 'Academic session is required',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Start date: ${dateKey(_startDate)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _isSubmitting ? null : _pickDate,
              ),
              AppTextField(
                controller: _timingController,
                label: 'Timing',
                hintText: 'e.g. Mon-Fri, 5-7 PM',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Timing is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _descriptionController,
                label: 'Description (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _admissionStatusController,
                label: 'Admission status',
                hintText: 'e.g. Admission open, Few seats left',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(
                  value,
                  message: 'Admission status is required',
                ),
              ),
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
