import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// The four events Set 4 is required to prepare notification hooks for.
enum NotificationEventType {
  homework,
  assignment,
  test,
  result;
}

/// Writes a record of a notification-worthy event to Firestore.
///
/// This is the "event hook" the spec asks for - not a push-notification
/// framework. There are no Cloud Functions in this project (see
/// docs/architecture.md's "Why no Cloud Functions"), so nothing server-side
/// can turn this into an actual FCM push yet; that needs either a Cloud
/// Function trigger or a manually-run sender, neither of which exists.
/// What's here is real and queryable: a durable trail of every
/// homework/assignment/test/result event, in the shape a future push
/// sender (or an in-app notifications feed) can consume directly.
///
/// Never throws - a failed hook write must not fail the action that
/// triggered it (e.g. creating homework should still succeed even if the
/// notification record can't be written).
Future<void> recordNotificationEvent(
  Ref ref, {
  required NotificationEventType type,
  required String batchId,
  required String title,
  required String body,
  required String relatedId,
  String? studentUid,
}) async {
  try {
    final now = Timestamp.now();
    await ref.read(firestoreProvider).collection(FirestoreCollections.notifications).add({
      'type': type.name,
      'batchId': batchId,
      'studentUid': studentUid,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'createdAt': now,
    });
  } catch (_) {
    // Best-effort - see the doc comment above.
  }
}
