import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/notice.dart';
import '../data/notice_read_state.dart';
import '../data/notice_repository.dart';

/// A teacher/student/parent's own notice inbox (Set 17 sections 11-13) -
/// published notices targeted at them only, never a draft (enforced by
/// [myNoticesProvider]/firestore.rules, not merely hidden client-side).
/// A parent sees exactly what the associated student account sees -
/// there is no separate parent login (see [NoticeAudience]'s doc
/// comment) - so this same screen serves student and parent alike.
class MyNoticesScreen extends ConsumerWidget {
  const MyNoticesScreen({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(myNoticesProvider);
    final readIds = ref.watch(myNoticeReadStatesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: SafeArea(
        child: noticesAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Unable to load notices. Please try again.\n$error'),
          data: (notices) {
            final active = notices.where((n) => !n.isExpired(DateTime.now())).toList();
            if (active.isEmpty) {
              return const EmptyView(message: 'No notices right now.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final notice = active[index];
                return _NoticeTile(
                  notice: notice,
                  isRead: readIds.contains(notice.noticeId),
                  onTap: () => context.push('$basePath/${notice.noticeId}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.isRead, required this.onTap});

  final Notice notice;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = notice.publishedAt ?? notice.createdAt;
    return Card(
      child: ListTile(
        leading: isRead
            ? const Icon(Icons.mark_email_read_outlined)
            : Icon(
                Icons.mark_email_unread_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
        title: Text(
          notice.title,
          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text('${notice.type.label} - ${dateKey(date)}'),
        onTap: onTap,
      ),
    );
  }
}
