import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/academic_config_controller.dart';
import '../data/academics_repositories.dart';
import '../data/board.dart';

/// Admin's board master (e.g. CBSE, BSEB, Others) - "Others" is not
/// special-cased here, it is just another board a future student-
/// admission screen can offer a free-text override for once selected.
class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(allBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Boards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBoardForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New board'),
      ),
      body: SafeArea(
        child: boardsAsync.when(
          loading: () => const LoadingView(message: 'Loading boards...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load boards.\n$error'),
          data: (boards) {
            if (boards.isEmpty) {
              return const EmptyView(
                message: 'No boards yet. Create one to get started.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: boards.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _BoardTile(board: boards[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BoardTile extends ConsumerWidget {
  const _BoardTile({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(board.name),
        subtitle: board.active ? null : const Text('Inactive'),
        onTap: () => _showBoardForm(context, existing: board),
        trailing: PopupMenuButton<bool>(
          onSelected: (active) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(academicConfigControllerProvider)
                  .setBoardActive(board, active);
            } on AcademicConfigFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: !board.active,
              child: Text(board.active ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showBoardForm(BuildContext context, {Board? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _BoardFormDialog(existing: existing),
  );
}

class _BoardFormDialog extends ConsumerStatefulWidget {
  const _BoardFormDialog({this.existing});

  final Board? existing;

  @override
  ConsumerState<_BoardFormDialog> createState() => _BoardFormDialogState();
}

class _BoardFormDialogState extends ConsumerState<_BoardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
          .read(academicConfigControllerProvider)
          .saveBoard(existing: widget.existing, name: _nameController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AcademicConfigFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New board' : 'Edit board'),
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
              label: 'Board name',
              enabled: !_isSubmitting,
              validator: (value) =>
                  Validators.required(value, message: 'Board name is required'),
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
}
