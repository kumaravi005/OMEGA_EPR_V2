import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/student_attendance_record.dart';
import '../../auth/application/auth_providers.dart';
import '../../homework/data/homework.dart';
import '../../homework/data/homework_repository.dart';
import '../../notifications/data/my_notifications_provider.dart';
import '../../tests/data/test_repository.dart';
import '../data/student_repository.dart';

/// Student/parent's landing screen: a summary dashboard (attendance, fee
/// due, upcoming tests, pending homework, latest result, notification
/// count) plus navigation to the full view-only screens for each.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    if (account == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text('Student - ${account.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final self = ref
                .watch(ownStudentProfileProvider(account.uid))
                .valueOrNull;
            if (self == null) return const LoadingView();
            return _DashboardBody(
              studentUid: self.uid,
              batchId: self.batchId,
              finalFee: self.finalFee,
            );
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.studentUid,
    required this.batchId,
    required this.finalFee,
  });

  final String studentUid;
  final String batchId;
  final double finalFee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(batchAttendanceProvider(batchId));
    final homeworkAsync = ref.watch(batchHomeworkProvider(batchId));
    final testsAsync = ref.watch(batchTestsProvider(batchId));
    final paymentsAsync = ref.watch(studentPaymentsProvider(studentUid));
    final notificationsAsync = ref.watch(myNotificationsProvider);

    final myAttendance =
        attendanceAsync.valueOrNull
            ?.where((r) => r.records.containsKey(studentUid))
            .toList() ??
        const [];
    final presentCount = myAttendance
        .where((r) => r.records[studentUid] == AttendanceStatus.present)
        .length;
    final attendancePct = myAttendance.isEmpty
        ? null
        : (presentCount / myAttendance.length) * 100;

    final pendingHomeworkCount = homeworkAsync.valueOrNull
        ?.where((h) => h.completionStatus == CompletionStatus.pending)
        .length;

    final now = DateTime.now();
    final upcomingTestsCount = testsAsync.valueOrNull
        ?.where((t) => t.date.isAfter(now))
        .length;

    final paid = paymentsAsync.valueOrNull == null
        ? null
        : totalPaid(paymentsAsync.valueOrNull!);
    final feeDue = paid == null ? null : finalFee - paid;

    final notificationCount = notificationsAsync.valueOrNull?.length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              label: 'Attendance',
              value: attendancePct == null
                  ? '-'
                  : '${attendancePct.toStringAsFixed(0)}%',
              icon: Icons.event_available_outlined,
            ),
            _StatCard(
              label: 'Fee due',
              value: feeDue == null ? '-' : '₹${feeDue.toStringAsFixed(0)}',
              icon: Icons.currency_rupee_outlined,
              highlight: feeDue != null && feeDue > 0,
            ),
            _StatCard(
              label: 'Upcoming tests',
              value: upcomingTestsCount == null ? '-' : '$upcomingTestsCount',
              icon: Icons.assignment_outlined,
            ),
            _StatCard(
              label: 'Pending homework',
              value: pendingHomeworkCount == null
                  ? '-'
                  : '$pendingHomeworkCount',
              icon: Icons.menu_book_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        NavTile(
          icon: Icons.notifications_outlined,
          label: notificationCount == null || notificationCount == 0
              ? 'Notifications'
              : 'Notifications ($notificationCount)',
          onTap: () => context.push(AppRoutes.studentNotifications),
        ),
        const SizedBox(height: AppSpacing.md),
        NavTile(
          icon: Icons.event_available_outlined,
          label: 'Attendance',
          onTap: () => context.push(AppRoutes.studentAttendance),
        ),
        NavTile(
          icon: Icons.menu_book_outlined,
          label: 'Homework',
          onTap: () => context.push(AppRoutes.studentHomework),
        ),
        NavTile(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Assignments',
          onTap: () => context.push(AppRoutes.studentAssignments),
        ),
        NavTile(
          icon: Icons.grade_outlined,
          label: 'Marks / Results',
          onTap: () => context.push(AppRoutes.studentResults),
        ),
        NavTile(
          icon: Icons.currency_rupee_outlined,
          label: 'Fees',
          onTap: () => context.push(AppRoutes.studentFees),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: highlight
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: highlight ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
