import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dashboard_header.dart';
import '../../../core/widgets/dashboard_stat_card.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/nav_grid_tile.dart';
import '../../../core/widgets/section_header.dart';
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
      body: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final self = ref
                .watch(ownStudentProfileProvider(account.uid))
                .valueOrNull;
            if (self == null) return const LoadingView();
            return _DashboardBody(
              studentUid: self.uid,
              studentName: account.displayName,
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
    required this.studentName,
    required this.batchId,
    required this.finalFee,
  });

  final String studentUid;
  final String studentName;
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
      padding: EdgeInsets.zero,
      children: [
        DashboardHeader(
          greeting: greetingFor(DateTime.now()),
          roleLabel: 'Student',
          name: studentName,
          onSignOut: () => ref.read(authControllerProvider).logout(),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.6,
                children: [
                  DashboardStatCard(
                    label: 'Attendance',
                    value: attendancePct == null
                        ? '-'
                        : '${attendancePct.toStringAsFixed(0)}%',
                    icon: Icons.event_available_outlined,
                    onTap: () => context.push(AppRoutes.studentAttendance),
                  ),
                  DashboardStatCard(
                    label: 'Fee due',
                    value: feeDue == null
                        ? '-'
                        : '₹${feeDue.toStringAsFixed(0)}',
                    icon: Icons.currency_rupee_outlined,
                    highlight: feeDue != null && feeDue > 0,
                    onTap: () => context.push(AppRoutes.studentFees),
                  ),
                  DashboardStatCard(
                    label: 'Upcoming tests',
                    value: upcomingTestsCount == null
                        ? '-'
                        : '$upcomingTestsCount',
                    icon: Icons.assignment_outlined,
                    onTap: () => context.push(AppRoutes.studentResults),
                  ),
                  DashboardStatCard(
                    label: 'Active homework',
                    value: activeHomeworkCount == null
                        ? '-'
                        : '$activeHomeworkCount',
                    icon: Icons.menu_book_outlined,
                    onTap: () => context.push(AppRoutes.studentAcademicWork),
                  ),
                ],
              ),
              const SectionHeader('Updates'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.95,
                children: [
                  NavGridTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    badgeCount: notificationCount ?? 0,
                    onTap: () =>
                        context.push(AppRoutes.studentNotifications),
                  ),
                  NavGridTile(
                    icon: Icons.notification_important_outlined,
                    label: 'Notices',
                    badgeCount: unreadNotices,
                    onTap: () => context.push(AppRoutes.studentNotices),
                  ),
                ],
              ),
              const SectionHeader('My academics'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.95,
                children: [
                  NavGridTile(
                    icon: Icons.event_available_outlined,
                    label: 'Attendance',
                    onTap: () => context.push(AppRoutes.studentAttendance),
                  ),
                  NavGridTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Homework',
                    onTap: () =>
                        context.push(AppRoutes.studentAcademicWork),
                  ),
                  NavGridTile(
                    icon: Icons.grade_outlined,
                    label: 'Results',
                    onTap: () => context.push(AppRoutes.studentResults),
                  ),
                  NavGridTile(
                    icon: Icons.currency_rupee_outlined,
                    label: 'Fees',
                    onTap: () => context.push(AppRoutes.studentFees),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
