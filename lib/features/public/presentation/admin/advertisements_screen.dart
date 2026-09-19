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
import '../../data/advertisement.dart';
import '../../data/public_content_repositories.dart';

class AdvertisementsScreen extends ConsumerWidget {
  const AdvertisementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(allAdvertisementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advertisements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New ad'),
      ),
      body: SafeArea(
        child: adsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load advertisements.\n$error'),
          data: (ads) {
            if (ads.isEmpty) {
              return const EmptyView(message: 'No advertisements yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: ads.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _Tile(ad: ads[index]),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.ad});

  final Advertisement ad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(ad.title),
        subtitle: Text(
          ad.isLive(DateTime.now())
              ? 'Live now - eligible for the popup'
              : 'Not currently live',
        ),
        onTap: () => _showForm(context, existing: ad),
        trailing: Switch(
          value: ad.active,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(publicContentControllerProvider)
                  .setAdvertisementActive(ad, value);
            } on PublicContentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}

void _showForm(BuildContext context, {Advertisement? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _FormDialog(existing: existing),
  );
}

class _FormDialog extends ConsumerStatefulWidget {
  const _FormDialog({this.existing});

  final Advertisement? existing;

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
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _buttonTextController = TextEditingController(
    text: widget.existing?.buttonText ?? '',
  );
  late final _buttonUrlController = TextEditingController(
    text: widget.existing?.buttonUrl ?? '',
  );
  late bool _active = widget.existing?.active ?? true;
  late AdButtonAction _buttonAction =
      widget.existing?.resolvedButtonAction ?? AdButtonAction.enquiry;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startDate;
    _endDate = widget.existing?.endDate;
  }

  @override
  void dispose() {
    _posterUrlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _buttonTextController.dispose();
    _buttonUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
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
          .saveAdvertisement(
            existing: widget.existing,
            posterUrl: _posterUrlController.text,
            title: _titleController.text,
            description: _descriptionController.text,
            buttonText: _buttonTextController.text,
            buttonUrl: _buttonUrlController.text,
            buttonAction: _buttonAction,
            active: _active,
            startDate: _startDate,
            endDate: _endDate,
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
        widget.existing == null ? 'New advertisement' : 'Edit advertisement',
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
                label: 'Poster image URL',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(
                  value,
                  message: 'Poster image URL is required',
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
                controller: _buttonTextController,
                label: 'Button text (optional)',
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AdButtonAction>(
                initialValue: _buttonAction,
                decoration: const InputDecoration(
                  labelText: 'When the button is tapped',
                ),
                items: [
                  for (final action in AdButtonAction.values)
                    DropdownMenuItem(value: action, child: Text(action.label)),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) setState(() => _buttonAction = value);
                      },
              ),
              if (_buttonAction == AdButtonAction.link) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _buttonUrlController,
                  label: 'Button link URL',
                  enabled: !_isSubmitting,
                  validator: (value) => Validators.required(
                    value,
                    message: 'Enter the link the button should open',
                  ),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _startDate == null
                      ? 'Active from (optional)'
                      : 'From ${dateKey(_startDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _isSubmitting ? null : () => _pickDate(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endDate == null
                      ? 'Active until (optional)'
                      : 'Until ${dateKey(_endDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _isSubmitting ? null : () => _pickDate(isStart: false),
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
