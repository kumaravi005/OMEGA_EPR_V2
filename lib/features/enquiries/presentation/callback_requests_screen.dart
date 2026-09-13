import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/enquiry_controller.dart';
import '../data/callback_request.dart';
import '../data/enquiry_repository.dart';

/// History of callback requests collected before Set 18 - new "request a
/// callback" submissions now write into `enquiries` instead (see
/// `EnquiryController.submitCallbackRequest`), so this screen and its
/// backing `callbackRequests` collection show only requests collected
/// before that change, preserved for admin history rather than migrated.
class CallbackRequestsScreen extends ConsumerWidget {
  const CallbackRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(allCallbackRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Callback requests (history)')),
      body: SafeArea(
        child: requestsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load requests.\n$error'),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyView(message: 'No callback requests yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _Tile(request: requests[index]),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.request});

  final CallbackRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(request.name),
        subtitle: Text(request.phone),
        leading: IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: () => callNumber(request.phone),
        ),
        trailing: DropdownButton<CallbackStatus>(
          value: request.status,
          items: CallbackStatus.values
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status.label)),
              )
              .toList(),
          onChanged: (status) async {
            if (status == null) return;
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(enquiryControllerProvider)
                  .updateCallbackStatus(request, status);
            } on EnquiryFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
        ),
      ),
    );
  }
}
