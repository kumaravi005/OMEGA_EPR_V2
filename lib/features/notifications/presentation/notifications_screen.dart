import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_event.dart';
import '../../../core/services/notification_hook.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academic_work/data/work_completion_repository.dart';
import '../../academic_work/presentation/work_completion_message_card.dart';
import '../data/my_notifications_provider.dart';

/// A read-only feed of notification events targeted to the signed-in
/// user (firestore.rules does the actual targeting - see
/// NotificationEvent/recordNotificationEvent). Shared by every role.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(myNotificationsProvider);
    // Students also see their homework/assignment status messages here
    // (empty for every other role).
    final completionViews = ref.watch(myWorkCompletionViewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: eventsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load notifications.\n$error'),
          data: (events) {
            final items = <({DateTime at, Widget tile})>[
              for (final event in events)
                (at: event.createdAt, tile: _Tile(event: event)),
              for (final view in completionViews)
                (
                  at: view.completion.markedAt,
                  tile: WorkCompletionMessageCard(view: view),
                ),
            ]..sort((a, b) => b.at.compareTo(a.at));
            if (items.isEmpty) {
              return const EmptyView(message: 'No notifications yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) => items[index].tile,
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.event});

  final NotificationEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(event.type)),
        title: Text(event.title),
        subtitle: Text(event.body),
      ),
    );
  }

  IconData _iconFor(NotificationEventType type) {
    switch (type) {
      case NotificationEventType.homework:
        return Icons.menu_book_outlined;
      case NotificationEventType.assignment:
        return Icons.assignment_turned_in_outlined;
      case NotificationEventType.test:
        return Icons.assignment_outlined;
      case NotificationEventType.result:
        return Icons.grade_outlined;
      case NotificationEventType.feePayment:
        return Icons.currency_rupee_outlined;
      case NotificationEventType.announcement:
        return Icons.campaign_outlined;
    }
  }
}
