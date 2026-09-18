import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/work_completion.dart';

/// The colors and icon that identify a completion status everywhere it
/// appears: green = completed, yellow = incomplete, red = not completed.
class CompletionTone {
  const CompletionTone({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

CompletionTone toneFor(WorkCompletionStatus status) => switch (status) {
  WorkCompletionStatus.completed => const CompletionTone(
    foreground: AppColors.success,
    background: AppColors.successSoft,
    border: AppColors.success,
    icon: Icons.check_circle,
  ),
  WorkCompletionStatus.incomplete => const CompletionTone(
    foreground: AppColors.onWarningSoft,
    background: AppColors.warningSoft,
    border: AppColors.warning,
    icon: Icons.timelapse,
  ),
  WorkCompletionStatus.notCompleted => const CompletionTone(
    foreground: AppColors.danger,
    background: AppColors.dangerSoft,
    border: AppColors.danger,
    icon: Icons.cancel,
  ),
};

/// A small pill showing a completion status in its tone.
class WorkCompletionChip extends StatelessWidget {
  const WorkCompletionChip({super.key, required this.status});

  final WorkCompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tone.icon, size: 14, color: tone.foreground),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: tone.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four counts for one piece of work as colored pills:
/// completed / incomplete / not completed / not marked yet.
class WorkCompletionSummaryRow extends StatelessWidget {
  const WorkCompletionSummaryRow({super.key, required this.summary});

  final WorkCompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _pill(
          'Completed ${summary.completed}',
          toneFor(WorkCompletionStatus.completed),
        ),
        _pill(
          'Incomplete ${summary.incomplete}',
          toneFor(WorkCompletionStatus.incomplete),
        ),
        _pill(
          'Not completed ${summary.notCompleted}',
          toneFor(WorkCompletionStatus.notCompleted),
        ),
        _pill('Not marked ${summary.notMarked}', null),
      ],
    );
  }

  Widget _pill(String label, CompletionTone? tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone?.background ?? AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone?.foreground ?? AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
