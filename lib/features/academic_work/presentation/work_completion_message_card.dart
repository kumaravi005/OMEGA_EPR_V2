import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/work_completion_message.dart';
import '../data/work_completion_repository.dart';
import 'work_completion_style.dart';

/// A student's completion status as a colored card: the status headline,
/// then the standard message in English and Hindi. Green for completed,
/// yellow for incomplete, red for not completed.
class WorkCompletionMessageCard extends StatelessWidget {
  const WorkCompletionMessageCard({super.key, required this.view});

  final WorkCompletionView view;

  @override
  Widget build(BuildContext context) {
    final completion = view.completion;
    final work = view.work;
    final tone = toneFor(completion.status);
    final message = buildWorkCompletionMessage(
      status: completion.status,
      type: work.type,
      title: work.title,
      subject: work.subject,
      dueDate: work.dueDate,
      remark: completion.remark,
      now: DateTime.now(),
    );
    final bodyStyle = TextStyle(
      color: tone.foreground,
      fontSize: 14,
      height: 20 / 14,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tone.icon, color: tone.foreground, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${completion.status.label} · ${completion.status.labelHindi}',
                  style: TextStyle(
                    color: tone.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message.english, style: bodyStyle),
          const SizedBox(height: AppSpacing.xs),
          Text(message.hindi, style: bodyStyle),
        ],
      ),
    );
  }
}
