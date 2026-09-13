import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../academic_work/data/academic_work.dart';
import '../../academic_work/data/academic_work_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/student_attendance_record.dart';
import '../../auth/application/auth_providers.dart';
import '../../fees/data/fee_calculator.dart';
import '../../fees/data/fee_payment_repository.dart';
import '../../notices/data/notice_read_state.dart';
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
    final academicWorkAsync = ref.watch(studentVisibleAcademicWorkProvider(batchId));
    final testsAsync = ref.watch(batchTestsProvider(batchId));
    final legacyPaymentsAsync = ref.watch(studentPaymentsProvider(studentUid));
    final feePaymentsAsync = ref.watch(studentFeePaymentsProvider(studentUid));
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

    final activeHomeworkCount = academicWorkAsync.valueOrNull
        ?.where(
          (w) =>
              w.type == AcademicWorkType.homework &&
              w.status == AcademicWorkStatus.published,
        )
        .length;

    final now = DateTime.now();
    final upcomingTestsCount = testsAsync.valueOrNull
        ?.where((t) => t.date.isAfter(now))
        .length;

    final feeDue = (legacyPaymentsAsync.valueOrNull == null || feePaymentsAsync.valueOrNull == null)
        ? null
        : combinedBalanceDue(
            finalFee: finalFee,
            feePayments: feePaymentsAsync.valueOrNull!,
            legacyPayments: legacyPaymentsAsync.valueOrNull!,
          );

    final notificationCount = notificationsAsync.valueOrNull?.length;
    final unreadNotices = ref.watch(unreadNoticeCountProvider);

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
              label: 'Active homework',
              value: activeHomeworkCount == null
                  ? '-'
                  : '$activeHomeworkCount',
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
        const SizedBox(height: AppSpacing.sm),
        NavTile(
          icon: Icons.notification_important_outlined,
          label: 'Notices',
          badgeCount: unreadNotices,
          onTap: () => context.push(AppRoutes.studentNotices),
        ),
        const SizedBox(height: AppSpacing.md),
        NavTile(
          icon: Icons.event_available_outlined,
          label: 'Attendance',
          onTap: () => context.push(AppRoutes.studentAttendance),
        ),
        NavTile(
          icon: Icons.menu_book_outlined,
          label: 'Homework & Assignments',
          onTap: () => context.push(AppRoutes.studentAcademicWork),
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
