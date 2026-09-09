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
import '../../data/announcement.dart';
import '../../data/public_content_repositories.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allAnnouncementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New announcement'),
      ),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load announcements.\n$error'),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No announcements yet.');
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _Tile(item: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => _showForm(context, existing: item),
        trailing: Switch(
          value: item.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(publicContentControllerProvider).setAnnouncementActive(item, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showForm(BuildContext context, {Announcement? existing}) {
  showDialog<void>(context: context, builder: (context) => _FormDialog(existing: existing));
}

class _FormDialog extends ConsumerStatefulWidget {
  const _FormDialog({this.existing});

  final Announcement? existing;

  @override
  ConsumerState<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends ConsumerState<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _bodyController = TextEditingController(text: widget.existing?.body ?? '');
  late bool _active = widget.existing?.active ?? true;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
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
          .saveAnnouncement(existing: widget.existing, title: _titleController.text, body: _bodyController.text, active: _active);
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
      title: Text(widget.existing == null ? 'New announcement' : 'Edit announcement'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppTextField(
              controller: _titleController,
              label: 'Title',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(value, message: 'Title is required'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _bodyController,
              label: 'Message',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(value, message: 'Message is required'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: _isSubmitting ? null : (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
