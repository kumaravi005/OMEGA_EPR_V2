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
import '../../data/banner_item.dart';
import '../../data/public_content_repositories.dart';

/// Admin management for the public homepage's hero carousel (Set 30).
/// Banners are ordered by [BannerItem.sortOrder] - drag to reorder here,
/// which the public carousel then reads directly (see
/// `PublicHomeScreen`'s `_HeroCarouselSection`).
class BannersScreen extends ConsumerWidget {
  const BannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(allBannersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hero banners')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBannerForm(
          context,
          nextSortOrder: bannersAsync.valueOrNull?.length ?? 0,
        ),
        icon: const Icon(Icons.add),
        label: const Text('New banner'),
      ),
      body: SafeArea(
        child: bannersAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load banners.\n$error'),
          data: (banners) {
            if (banners.isEmpty) {
              return const EmptyView(message: 'No banners yet.');
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
                    'Recommended image size: 1200 x 540 px (20:9), JPG or PNG. '
                    'Drag to reorder - the top banner shows first on the site.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: banners.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      final reordered = banners.toList();
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(publicContentControllerProvider)
                            .reorderBanners(reordered);
                      } on PublicContentFailure catch (failure) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return _BannerTile(
                        key: ValueKey(banner.bannerId),
                        banner: banner,
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

class _BannerTile extends ConsumerWidget {
  const _BannerTile({super.key, required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            width: 64,
            height: 64 * 9 / 20,
            child: Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined, size: 18),
              ),
            ),
          ),
        ),
        title: Text(banner.title),
        subtitle: Text(
          banner.isLive(DateTime.now()) ? 'Live now' : 'Not currently live',
        ),
        onTap: () => _showBannerForm(
          context,
          existing: banner,
          nextSortOrder: banner.sortOrder,
        ),
        trailing: Switch(
          value: banner.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(publicContentControllerProvider)
                  .setBannerActive(banner, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showBannerForm(
  BuildContext context, {
  BannerItem? existing,
  required int nextSortOrder,
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _BannerFormDialog(existing: existing, nextSortOrder: nextSortOrder),
  );
}

class _BannerFormDialog extends ConsumerStatefulWidget {
  const _BannerFormDialog({this.existing, required this.nextSortOrder});

  final BannerItem? existing;
  final int nextSortOrder;

  @override
  ConsumerState<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends ConsumerState<_BannerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _imageUrlController = TextEditingController(
    text: widget.existing?.imageUrl ?? '',
  );
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _ctaTextController = TextEditingController(
    text: widget.existing?.ctaText ?? '',
  );
  late final _ctaUrlController = TextEditingController(
    text: widget.existing?.ctaUrl ?? '',
  );
  late bool _active = widget.existing?.active ?? true;
  DateTime? _displayFrom;
  DateTime? _displayUntil;

  bool _isSubmitting = false;
  String? _errorMessage;
  String _previewUrl = '';

  @override
  void initState() {
    super.initState();
    _displayFrom = widget.existing?.displayFrom;
    _displayUntil = widget.existing?.displayUntil;
    _previewUrl = _imageUrlController.text.trim();
    _imageUrlController.addListener(_onImageUrlChanged);
  }

  void _onImageUrlChanged() {
    final trimmed = _imageUrlController.text.trim();
    if (trimmed != _previewUrl) setState(() => _previewUrl = trimmed);
  }

  @override
  void dispose() {
    _imageUrlController.removeListener(_onImageUrlChanged);
    _imageUrlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _ctaTextController.dispose();
    _ctaUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => isFrom ? _displayFrom = picked : _displayUntil = picked);
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
          .saveBanner(
            existing: widget.existing,
            imageUrl: _imageUrlController.text,
            title: _titleController.text,
            description: _descriptionController.text,
            ctaText: _ctaTextController.text,
            ctaUrl: _ctaUrlController.text,
            active: _active,
            displayFrom: _displayFrom,
            displayUntil: _displayUntil,
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
      title: Text(widget.existing == null ? 'New banner' : 'Edit banner'),
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
              Text(
                'Recommended size: 1200 x 540 px (20:9 aspect ratio), JPG or PNG.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_previewUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: AspectRatio(
                    aspectRatio: 20 / 9,
                    child: Image.network(
                      _previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppTextField(
                controller: _imageUrlController,
                label: 'Image URL',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(
                  value,
                  message: 'Image URL is required',
                ),
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
                controller: _descriptionController,
                label: 'Description (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _ctaTextController,
                label: 'CTA button text (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _ctaUrlController,
                label: 'CTA link URL (optional)',
                enabled: !_isSubmitting,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _displayFrom == null
                      ? 'Display from (optional)'
                      : 'From ${dateKey(_displayFrom!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _isSubmitting ? null : () => _pickDate(isFrom: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _displayUntil == null
                      ? 'Display until (optional)'
                      : 'Until ${dateKey(_displayUntil!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _isSubmitting ? null : () => _pickDate(isFrom: false),
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
