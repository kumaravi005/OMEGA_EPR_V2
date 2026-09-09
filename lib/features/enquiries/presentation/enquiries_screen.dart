import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/enquiry_controller.dart';
import '../data/enquiry.dart';
import '../data/enquiry_repository.dart';

/// Admin manages admission enquiries submitted from the public site.
/// There is deliberately no separate "telecaller" role - admin does this
/// directly.
class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enquiriesAsync = ref.watch(allEnquiriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admission enquiries')),
      body: SafeArea(
        child: enquiriesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load enquiries.\n$error'),
          data: (enquiries) {
            if (enquiries.isEmpty) return const EmptyView(message: 'No enquiries yet.');
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: enquiries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _EnquiryTile(enquiry: enquiries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EnquiryTile extends ConsumerWidget {
  const _EnquiryTile({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(enquiry.name, style: Theme.of(context).textTheme.titleLarge),
            if (enquiry.className != null || enquiry.board != null)
              Text('${enquiry.className ?? ''} ${enquiry.board ?? ''}'.trim()),
            Text(enquiry.primaryPhone),
            if (enquiry.message != null && enquiry.message!.isNotEmpty) Text(enquiry.message!),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  tooltip: 'Call',
                  onPressed: () => callNumber(enquiry.primaryPhone),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  tooltip: 'WhatsApp',
                  onPressed: () => openWhatsApp(enquiry.primaryPhone),
                ),
                const Spacer(),
                DropdownButton<EnquiryStatus>(
                  value: enquiry.status,
                  items: EnquiryStatus.values
                      .map((status) => DropdownMenuItem(value: status, child: Text(status.label)))
                      .toList(),
                  onChanged: (status) async {
                    if (status == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(enquiryControllerProvider).updateStatus(enquiry, status);
                    } on EnquiryFailure catch (failure) {
                      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
