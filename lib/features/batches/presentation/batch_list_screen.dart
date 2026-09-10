import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/batch_controller.dart';
import '../data/batch.dart';
import '../data/batch_repository.dart';

class BatchListScreen extends ConsumerWidget {
  const BatchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(allBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Batches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBatchForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New batch'),
      ),
      body: SafeArea(
        child: batchesAsync.when(
          loading: () => const LoadingView(message: 'Loading batches...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load batches.\n$error'),
          data: (batches) {
            if (batches.isEmpty) {
              return const EmptyView(
                message:
                    'No batches yet. Create one to start admitting students.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: batches.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _BatchTile(batch: batches[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BatchTile extends ConsumerWidget {
  const _BatchTile({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(batch.name),
        subtitle: Text(
          'Monthly: ₹${batch.standardMonthlyFee.toStringAsFixed(0)}   '
          'Installment: ₹${batch.standardInstallmentFee.toStringAsFixed(0)}'
          '${batch.active ? '' : '   (inactive)'}',
        ),
        onTap: () => _showBatchForm(context, existing: batch),
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

void _showBatchForm(BuildContext context, {Batch? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _BatchFormDialog(existing: existing),
  );
}

class _BatchFormDialog extends ConsumerStatefulWidget {
  const _BatchFormDialog({this.existing});

  final Batch? existing;

  @override
  ConsumerState<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends ConsumerState<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _monthlyController = TextEditingController(
    text: widget.existing?.standardMonthlyFee.toStringAsFixed(0) ?? '',
  );
  late final _installmentController = TextEditingController(
    text: widget.existing?.standardInstallmentFee.toStringAsFixed(0) ?? '',
  );

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _monthlyController.dispose();
    _installmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final monthly = double.parse(_monthlyController.text);
    final installment = double.parse(_installmentController.text);

    try {
      final controller = ref.read(batchControllerProvider);
      if (widget.existing == null) {
        await controller.createBatch(
          name: _nameController.text,
          standardMonthlyFee: monthly,
          standardInstallmentFee: installment,
        );
      } else {
        await controller.updateBatch(
          widget.existing!,
          name: _nameController.text,
          standardMonthlyFee: monthly,
          standardInstallmentFee: installment,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on BatchFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New batch' : 'Edit batch'),
      content: Form(
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
              controller: _nameController,
              label: 'Batch name',
              enabled: !_isSubmitting,
              validator: (value) =>
                  Validators.required(value, message: 'Batch name is required'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _monthlyController,
              label: 'Standard monthly fee',
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _installmentController,
              label: 'Standard installment fee',
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateAmount,
            ),
          ],
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

  String? _validateAmount(String? value) {
    final requiredError = Validators.required(value, message: 'Required');
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }
}
