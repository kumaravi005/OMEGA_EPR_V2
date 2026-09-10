import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_event.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../student/data/student_repository.dart';

/// Every notification the signed-in user is allowed to see, newest first.
///
/// Admin/teacher get an unconstrained scan - their `list` rule branch
/// (`isAdmin() || isTeacher()`) is role-only, so Firestore allows it
/// regardless of query shape. A student's rule branch
/// (`isTargetOfNotification()`) depends on `batchId`/`studentUid`
/// per-document, which Firestore can only verify against a query
/// constrained to match (see FirestoreRepository.watchWhere) - so this
/// runs three simple, always-auto-indexed single-field queries
/// (broadcasts, this student's batch, and events targeted at this
/// student directly) and merges them, rather than one `Filter.or` query
/// across two different fields - that may need a manually-created
/// composite index Firestore won't auto-provision, not something this
/// project wants to depend on for a notification feed to work at all.
final myNotificationsProvider = StreamProvider<List<NotificationEvent>>((ref) {
  final account = ref.watch(currentUserAccountProvider).valueOrNull;
  if (account == null) return Stream.value(const <NotificationEvent>[]);

  final repository = ref.watch(notificationRepositoryProvider);

  if (account.role == UserRole.admin || account.role == UserRole.teacher) {
    return repository.watchAll().map(_sorted);
  }

  final student = ref.watch(ownStudentProfileProvider(account.uid)).valueOrNull;
  if (student == null) return Stream.value(const <NotificationEvent>[]);

  final sources = <_Source>[
    (
      index: 0,
      stream: repository.watchWhere(
        (query) => query.where('batchId', isNull: true),
      ),
    ),
    (
      index: 1,
      stream: repository.watchWhere(
        (query) => query.where('batchId', isEqualTo: student.batchId),
      ),
    ),
    (
      index: 2,
      stream: repository.watchWhere(
        (query) => query.where('studentUid', isEqualTo: account.uid),
      ),
    ),
  ];
  final latest = List<List<NotificationEvent>>.filled(sources.length, const []);

  return StreamGroup.merge([
    for (final source in sources)
      source.stream.map((events) => (source.index, events)),
  ]).map((update) {
    latest[update.$1] = update.$2;
    final byId = {
      for (final events in latest)
        for (final event in events) event.eventId: event,
    };
    return _sorted(byId.values.toList());
  });
});

typedef _Source = ({int index, Stream<List<NotificationEvent>> stream});

List<NotificationEvent> _sorted(List<NotificationEvent> events) =>
    events.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
