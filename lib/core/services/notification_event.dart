import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/firestore_document.dart';
import '../../data/repositories/firestore_repository.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';
import 'notification_hook.dart';

/// A notification event, as read back from Firestore - see
/// `recordNotificationEvent` for how these get written.
class NotificationEvent implements FirestoreDocument {
  const NotificationEvent({
    required this.eventId,
    required this.type,
    required this.batchId,
    required this.studentUid,
    required this.title,
    required this.body,
    required this.relatedId,
    required this.createdAt,
  });

  factory NotificationEvent.fromMap(String id, Map<String, dynamic> map) {
    return NotificationEvent(
      eventId: id,
      type: NotificationEventType.values.firstWhere(
        (t) => t.name == map['type'],
      ),
      batchId: map['batchId'] as String?,
      studentUid: map['studentUid'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      relatedId: map['relatedId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  final String eventId;
  final NotificationEventType type;
  final String? batchId;
  final String? studentUid;
  final String title;
  final String body;
  final String relatedId;
  final DateTime createdAt;

  @override
  String get id => eventId;

  @override
  Map<String, dynamic> toMap() => throw UnsupportedError(
    'Notifications are written via recordNotificationEvent only.',
  );
}

final notificationRepositoryProvider =
    Provider<FirestoreRepository<NotificationEvent>>((ref) {
      return FirestoreRepository<NotificationEvent>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.notifications,
        fromFirestore: NotificationEvent.fromMap,
        toFirestore: (event) => event.toMap(),
      );
    });

// The read-side `myNotificationsProvider` (role-aware: admin/teacher get
// an unconstrained scan, a student gets a query scoped to their own
// batch/broadcast/personal events) lives in
// features/notifications/data/my_notifications_provider.dart, not here -
// it needs `currentUserAccountProvider` and a student's own batchId,
// which `core/` never imports (see docs/development-rules.md).
