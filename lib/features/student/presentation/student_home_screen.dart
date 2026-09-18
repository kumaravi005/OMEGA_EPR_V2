import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/logout_row.dart';
import '../../../core/widgets/quick_tile.dart';
import '../../../core/widgets/role_dashboard_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../academic_work/data/academic_work.dart';
import '../../academic_work/data/academic_work_repository.dart';
import '../../academic_work/data/work_completion_repository.dart';
import '../../academic_work/presentation/work_completion_popup_host.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/student_attendance_record.dart';
import '../../auth/application/auth_providers.dart';
import '../../fees/data/fee_calculator.dart';
import '../../fees/data/fee_payment_repository.dart';
import '../../notices/data/notice.dart';
import '../../notices/data/notice_read_state.dart';
import '../../notices/data/notice_repository.dart';
import '../../notifications/data/my_notifications_provider.dart';
import '../../tests/data/test_repository.dart';
import '../data/student_repository.dart';

/// Student/parent's landing screen: a summary dashboard (attendance, fee
/// due, upcoming tests, pending homework, latest notice) plus navigation to
/// the full view-only screens for each. Notifications/notices live in the
/// header as icon buttons and Logout is its own row at the bottom (per the
/// post-Set-33 redesign brief).
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    if (account == null) return const Scaffold(body: LoadingView());

    return WorkCompletionPopupHost(
      child: Scaffold(
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
                photoUrl: self.photoUrl,
                batchId: self.batchId,
                finalFee: self.finalFee,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.studentUid,
    required this.studentName,
    required this.photoUrl,
    required this.batchId,
    required this.finalFee,
  });

  final String studentUid;
  final String studentName;
  final String? photoUrl;
  final String batchId;
  final double finalFee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(batchAttendanceProvider(batchId));
    final academicWorkAsync = ref.watch(
      studentVisibleAcademicWorkProvider(batchId),
    );
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

    final feeDue =
        (legacyPaymentsAsync.valueOrNull == null ||
            feePaymentsAsync.valueOrNull == null)
        ? null
        : combinedBalanceDue(
            finalFee: finalFee,
            feePayments: feePaymentsAsync.valueOrNull!,
            legacyPayments: legacyPaymentsAsync.valueOrNull!,
          );

    final notificationCount =
        (notificationsAsync.valueOrNull?.length ?? 0) +
        ref.watch(myWorkCompletionViewsProvider).length;
    final unreadNotices = ref.watch(unreadNoticeCountProvider);

    final recentNotices = [
      ...(ref.watch(myNoticesProvider).valueOrNull ?? const <Notice>[]).where(
        (n) => !n.isExpired(now),
      ),
    ]..sort((a, b) => _noticeDate(b).compareTo(_noticeDate(a)));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RoleDashboardHeader(
          greeting: greetingFor(now),
          name: studentName,
          roleLabel: 'Student',
          photoUrl: photoUrl,
          notificationCount: notificationCount,
          noticeCount: unreadNotices,
          onNotifications: () => context.push(AppRoutes.studentNotifications),
          onNotices: () => context.push(AppRoutes.studentNotices),
        ),
        // The whole body is nudged up so the first row of stat cards
        // overlaps the header's rounded bottom edge; the layout still
        // reserves the space, which just becomes extra room below Logout.
        Transform.translate(
          offset: const Offset(0, -34),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: 124,
                  ),
                  children: [
                    _StatTile(
                      label: 'Attendance',
                      value: attendancePct == null
                          ? '--'
                          : '${attendancePct.toStringAsFixed(0)}%',
                      icon: Icons.event_available_outlined,
                      onTap: () => context.push(AppRoutes.studentAttendance),
                    ),
                    _StatTile(
                      label: 'Fee due',
                      value: feeDue == null ? '--' : _formatRupees(feeDue),
                      icon: Icons.currency_rupee_outlined,
                      isDanger: feeDue != null && feeDue > 0,
                      onTap: () => context.push(AppRoutes.studentFees),
                    ),
                    _StatTile(
                      label: 'Upcoming tests',
                      value: upcomingTestsCount == null
                          ? '--'
                          : '$upcomingTestsCount',
                      icon: Icons.assignment_outlined,
                      onTap: () => context.push(AppRoutes.studentResults),
                    ),
                    _StatTile(
                      label: 'Active homework',
                      value: activeHomeworkCount == null
                          ? '--'
                          : '$activeHomeworkCount',
                      icon: Icons.menu_book_outlined,
                      onTap: () => context.push(AppRoutes.studentAcademicWork),
                    ),
                  ],
                ),
                if (recentNotices.isNotEmpty) ...[
                  SectionHeader(
                    'Recent notices',
                    trailing: TextButton(
                      onPressed: () => context.push(AppRoutes.studentNotices),
                      child: const Text('View all'),
                    ),
                  ),
                  _RecentNoticeCard(
                    notice: recentNotices.first,
                    onTap: () => context.push(
                      '${AppRoutes.studentNotices}/${recentNotices.first.noticeId}',
                    ),
                  ),
                ],
                const SectionHeader('My academics'),
                Row(
                  children: [
                    Expanded(
                      child: QuickTile(
                        icon: Icons.event_available_outlined,
                        label: 'Attendance',
                        onTap: () => context.push(AppRoutes.studentAttendance),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: QuickTile(
                        icon: Icons.menu_book_outlined,
                        label: 'Homework',
                        onTap: () =>
                            context.push(AppRoutes.studentAcademicWork),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: QuickTile(
                        icon: Icons.grade_outlined,
                        label: 'Results',
                        onTap: () => context.push(AppRoutes.studentResults),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: QuickTile(
                        icon: Icons.currency_rupee_outlined,
                        label: 'Fees',
                        onTap: () => context.push(AppRoutes.studentFees),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                LogoutRow(
                  onTap: () => ref.read(authControllerProvider).logout(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

DateTime _noticeDate(Notice notice) => notice.publishedAt ?? notice.createdAt;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "₹6,000" / "₹1,50,000" - Indian digit grouping, no decimals.
String _formatRupees(double amount) {
  final digits = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 &&
        (remaining == 4 || (remaining > 4 && remaining.isEven))) {
      buffer.write(',');
    }
  }
  return '${amount < 0 ? '-' : ''}₹$buffer';
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconChip(icon: icon, isDanger: isDanger),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isDanger
                          ? AppColors.danger
                          : AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 28 / 24,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentNoticeCard extends StatelessWidget {
  const _RecentNoticeCard({required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = _noticeDate(notice);
    return ShadowCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const IconChip(icon: Icons.notifications_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 22 / 16,
                    ),
                  ),
                  Text(
                    'Posted ${date.day} ${_months[date.month - 1]}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
            if (notice.type == NoticeType.important) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'IMPORTANT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 14 / 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
