import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/work_completion_controller.dart';
import '../data/work_completion_repository.dart';
import 'work_completion_message_card.dart';

/// Wraps the student's home screen and pops up a colored, bilingual message
/// whenever a teacher marks one of their homework/assignments - straight
/// away if the app is open, or the next time they open it (a record stays
/// "unseen" until the popup is dismissed).
///
/// This is an in-app popup, not a push notification: there are no Cloud
/// Functions/FCM on this plan (see docs/architecture.md), so nothing can
/// reach a phone whose app is closed.
class WorkCompletionPopupHost extends ConsumerStatefulWidget {
  const WorkCompletionPopupHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WorkCompletionPopupHost> createState() =>
      _WorkCompletionPopupHostState();
}

class _WorkCompletionPopupHostState
    extends ConsumerState<WorkCompletionPopupHost> {
  bool _showing = false;

  /// `<id>@<markedAt>` of everything already popped up this session, so a
  /// failed `seenAt` write (e.g. offline) can't make the same popup loop.
  /// A re-mark changes `markedAt`, so it correctly shows again.
  final _shownThisSession = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  String _key(WorkCompletionView view) =>
      '${view.completion.id}@${view.completion.markedAt.millisecondsSinceEpoch}';

  void _showIfNeeded() {
    if (!mounted || _showing) return;
    final pending = [
      for (final view in ref.read(myWorkCompletionViewsProvider))
        if (view.completion.isUnseen && !_shownThisSession.contains(_key(view)))
          view,
    ];
    if (pending.isEmpty) return;

    _showing = true;
    _shownThisSession.addAll(pending.map(_key));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WorkCompletionDialog(views: pending),
    ).whenComplete(() async {
      _showing = false;
      try {
        await ref
            .read(workCompletionControllerProvider)
            .markSeen(pending.map((view) => view.completion));
      } catch (_) {
        // Best-effort - the session set above stops this popup repeating.
      }
      // Something newer may have arrived while the dialog was open.
      if (mounted) _showIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myWorkCompletionViewsProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
    });
    return widget.child;
  }
}

class _WorkCompletionDialog extends StatelessWidget {
  const _WorkCompletionDialog({required this.views});

  final List<WorkCompletionView> views;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Homework update\nहोमवर्क अपडेट',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < views.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                WorkCompletionMessageCard(view: views[i]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK · ठीक है'),
        ),
      ],
    );
  }
}
