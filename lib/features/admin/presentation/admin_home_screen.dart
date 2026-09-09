import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../application/admin_account_controller.dart';

/// Admin account-management foundation: list accounts, create one, and
/// reset/toggle an existing one. Full admin dashboards (batches, fees,
/// reports, ...) are a later phase.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminCreateAccount),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create account'),
      ),
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const LoadingView(message: 'Loading accounts...'),
          error: (error, stackTrace) => ErrorView(message: 'Could not load accounts.\n$error'),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const EmptyView(message: 'No accounts yet. Create the first one below.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _AccountTile(account: accounts[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSession = account.session != null;

    return Card(
      child: ListTile(
        title: Text('${account.displayName} (${account.accountId})'),
        subtitle: Text(
          '${_roleLabel(account.role)} - ${account.active ? 'Active' : 'Inactive'}'
          '${hasSession ? ' - signed in on a device' : ''}',
        ),
        trailing: PopupMenuButton<_AccountAction>(
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _AccountAction.toggleActive,
              child: Text(account.active ? 'Deactivate' : 'Activate'),
            ),
            if (hasSession) const PopupMenuItem(value: _AccountAction.resetSession, child: Text('Reset session')),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, _AccountAction action) async {
    final controller = ref.read(adminAccountControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case _AccountAction.toggleActive:
          await controller.setActive(account.uid, !account.active);
        case _AccountAction.resetSession:
          await controller.resetSession(account.uid);
      }
    } on AdminActionFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student / Parent';
    }
  }
}

enum _AccountAction { toggleActive, resetSession }
