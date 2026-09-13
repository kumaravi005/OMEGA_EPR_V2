import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/enquiry_controller.dart';
import '../data/enquiry.dart';
import '../data/enquiry_repository.dart';

/// Visitor Information / Enquiry Information, plus status/call actions
/// (Set 18 section 13) - admin-only, reached from [EnquiriesScreen].
class EnquiryDetailsScreen extends ConsumerWidget {
  const EnquiryDetailsScreen({super.key, required this.enquiryId});

  final String enquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enquiriesAsync = ref.watch(allEnquiriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enquiry details')),
      body: SafeArea(
        child: enquiriesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load this enquiry.\n$error'),
          data: (enquiries) {
            final enquiry = enquiries.where((e) => e.enquiryId == enquiryId).firstOrNull;
            if (enquiry == null) {
              return const ErrorView(message: 'Not found.');
            }
            return _DetailsBody(enquiry: enquiry);
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    enquiry.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(label: Text(enquiry.enquiryType.label)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visitor information', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (enquiry.guardianName != null)
                    _InfoRow(label: "Guardian's name", value: enquiry.guardianName!),
                  if (enquiry.className != null)
                    _InfoRow(label: 'Class', value: enquiry.className!),
                  if (enquiry.boardDisplay != null)
                    _InfoRow(label: 'Board', value: enquiry.boardDisplay!),
                  _InfoRow(label: 'Primary phone', value: enquiry.primaryPhone),
                  if (enquiry.secondaryPhone != null)
                    _InfoRow(label: 'Secondary phone', value: enquiry.secondaryPhone!),
                  if (enquiry.message != null && enquiry.message!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(enquiry.message!),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                          onPressed: () => callNumber(enquiry.primaryPhone),
                        ),
                      ),
                      if (enquiry.secondaryPhone != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call secondary'),
                            onPressed: () => callNumber(enquiry.secondaryPhone!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enquiry information', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Created', value: dateKey(enquiry.createdAt)),
                  _InfoRow(label: 'Updated', value: dateKey(enquiry.updatedAt)),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<EnquiryStatus>(
                    initialValue: enquiry.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: EnquiryStatus.values
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
                            .updateStatus(enquiry, status);
                      } on EnquiryFailure catch (failure) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
