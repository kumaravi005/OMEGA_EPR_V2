import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../data/notice.dart';

/// Full details of one public notice, for an unauthenticated visitor
/// (Set 18 section 7) - a plain dialog, not a routed screen, since the
/// public home page is the only place this is ever reached from ("do not
/// create unnecessary pages if existing screens/components can safely be
/// reused"). Shows only title/type/message/date - never `createdBy`,
/// internal ids, targeting data, or read state, none of which this
/// dialog is even given (it takes a plain [Notice], but only reads the
/// public-safe fields below).
Future<void> showPublicNoticeDialog(BuildContext context, Notice notice) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(notice.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(
                notice.type == NoticeType.other
                    ? (notice.otherTypeLabel ?? notice.type.label)
                    : notice.type.label,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(notice.message),
            const SizedBox(height: AppSpacing.sm),
            Text(
              dateKey(notice.publishedAt ?? notice.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
