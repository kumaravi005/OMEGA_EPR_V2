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
import '../../data/gallery_item.dart';
import '../../data/public_content_repositories.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allGalleryItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGalleryForm(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('New image'),
      ),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load the gallery.\n$error'),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No gallery images yet.');
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _GalleryTile(item: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _GalleryTile extends ConsumerWidget {
  const _GalleryTile({required this.item});

  final GalleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
        ),
        title: Text(item.title),
        subtitle: Text(item.category ?? 'Uncategorised'),
        onTap: () => _showGalleryForm(context, existing: item),
        trailing: Switch(
          value: item.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(publicContentControllerProvider).setGalleryActive(item, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showGalleryForm(BuildContext context, {GalleryItem? existing}) {
  showDialog<void>(context: context, builder: (context) => _GalleryFormDialog(existing: existing));
}

class _GalleryFormDialog extends ConsumerStatefulWidget {
  const _GalleryFormDialog({this.existing});

  final GalleryItem? existing;

  @override
  ConsumerState<_GalleryFormDialog> createState() => _GalleryFormDialogState();
}

class _GalleryFormDialogState extends ConsumerState<_GalleryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _imageUrlController = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late final _categoryController = TextEditingController(text: widget.existing?.category ?? '');
  late bool _active = widget.existing?.active ?? true;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _imageUrlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
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
          .saveGalleryItem(
            existing: widget.existing,
            imageUrl: _imageUrlController.text,
            title: _titleController.text,
            description: _descriptionController.text,
            category: _categoryController.text,
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
      title: Text(widget.existing == null ? 'New gallery image' : 'Edit gallery image'),
      content: SingleChildScrollView(
        child: Form(
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
                controller: _imageUrlController,
                label: 'Image URL',
                hintText: 'https://...',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(value, message: 'Image URL is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(value, message: 'Title is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _descriptionController, label: 'Description (optional)', enabled: !_isSubmitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _categoryController, label: 'Category (optional)', enabled: !_isSubmitting),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active (visible on the public site)'),
                value: _active,
                onChanged: _isSubmitting ? null : (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
