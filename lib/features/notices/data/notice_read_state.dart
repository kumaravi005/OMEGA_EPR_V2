import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/models/firestore_document.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../auth/application/auth_providers.dart';
import 'notice_repository.dart';

/// A signed-in user's own "I opened this" marker for one notice, at
/// `users/{uid}/noticeReadStates/{noticeId}` (Set 17 section 15) - the
/// document id IS the notice id, so [noticeId] below is only for
/// convenience, never queried separately. Absence of a document means
/// unread; nothing is ever written for an unread notice (no fan-out of
/// "unread" rows for ~200 users x every notice - see section 16).
/// Immutable once created (firestore.rules denies `update`) - the app
/// never needs to "unread" something, so [markNoticeRead] checks the
/// current state first and only ever creates the document once.
class NoticeReadState implements FirestoreDocument {
  const NoticeReadState({required this.noticeId, required this.readAt});

  factory NoticeReadState.fromMap(String id, Map<String, dynamic> map) {
    return NoticeReadState(
      noticeId: id,
      readAt: (map['readAt'] as Timestamp).toDate(),
    );
  }

  final String noticeId;
  final DateTime readAt;

  @override
  String get id => noticeId;

  @override
  Map<String, dynamic> toMap() => {'readAt': Timestamp.fromDate(readAt)};
}

final noticeReadStateRepositoryProvider =
    Provider.family<FirestoreRepository<NoticeReadState>, String>((ref, uid) {
      return FirestoreRepository<NoticeReadState>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: '${FirestoreCollections.users}/$uid/noticeReadStates',
        fromFirestore: NoticeReadState.fromMap,
        toFirestore: (state) => state.toMap(),
      );
    });

/// Every notice id the signed-in user has opened - a tiny, per-user
/// subcollection (bounded by the total number of notices, ~200 at this
/// project's scale - section 26), cheap to scan in full. Used to derive
/// read/unread per tile and the unread count, never a global counter
/// (section 16).
final myNoticeReadStatesProvider = StreamProvider<Set<String>>((ref) {
  final account = ref.watch(currentUserAccountProvider).valueOrNull;
  if (account == null) return Stream.value(const <String>{});
  return ref
      .watch(noticeReadStateRepositoryProvider(account.uid))
      .watchAll()
      .map((states) => states.map((state) => state.noticeId).toSet());
});

/// Unread = eligible published notices the user has not yet opened.
/// Calculated client-side from two already-live streams, not a stored
/// counter (section 16: "prioritize correctness and simplicity over
/// premature optimization" at ~200 users).
final unreadNoticeCountProvider = Provider<int>((ref) {
  final notices = ref.watch(myNoticesProvider).valueOrNull ?? const [];
  final readIds = ref.watch(myNoticeReadStatesProvider).valueOrNull ?? const {};
  return notices.where((notice) => !readIds.contains(notice.noticeId)).length;
});

/// Marks [noticeId] as read for the signed-in user - a no-op if it's
/// already marked (so reopening an already-read notice never attempts a
/// second write, which firestore.rules would reject as an `update` since
/// the read-state document already exists - see the class doc comment).
/// Opening a notice must never fail the screen just because this
/// best-effort write fails (e.g. a transient network issue). Takes a
/// [WidgetRef] (rather than a plain [Ref]) since this is only ever
/// called from widget code (`NoticeDetailsScreen`), not a controller.
Future<void> markNoticeRead(WidgetRef ref, String noticeId) async {
  final account = ref.read(currentUserAccountProvider).valueOrNull;
  if (account == null) return;
  final alreadyRead =
      ref.read(myNoticeReadStatesProvider).valueOrNull?.contains(noticeId) ??
      false;
  if (alreadyRead) return;
  try {
    await ref
        .read(noticeReadStateRepositoryProvider(account.uid))
        .set(noticeId, NoticeReadState(noticeId: noticeId, readAt: DateTime.now()));
  } catch (_) {
    // Best-effort - see the doc comment above.
  }
}
