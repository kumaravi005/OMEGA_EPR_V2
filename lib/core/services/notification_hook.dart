import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// The notification-worthy events this project prepares hooks for.
enum NotificationEventType {
  homework,
  assignment,
  test,
  result,
  feePayment,
  announcement;
}

/// Writes a record of a notification-worthy event to Firestore.
///
/// This is the "event hook" the spec asks for - not a push-notification
/// framework. There are no Cloud Functions in this project (see
/// docs/architecture.md's "Why no Cloud Functions"), so nothing server-side
/// can turn this into an actual FCM push yet; that needs either a Cloud
/// Function trigger or a manually-run sender, neither of which exists.
/// What's here is real and queryable: a durable trail of every
/// homework/assignment/test/result/fee-payment/announcement event, in the
/// shape a future push sender (or an in-app notifications feed) can
/// consume directly - see NotificationsScreen for the feed that already
/// reads it.
///
/// [batchId] is `null` for a broadcast event (currently only
/// announcements) that targets everyone, not one batch.
///
/// Never throws - a failed hook write must not fail the action that
/// triggered it (e.g. creating homework should still succeed even if the
/// notification record can't be written).
Future<void> recordNotificationEvent(
  Ref ref, {
  required NotificationEventType type,
  required String? batchId,
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

/// A fee payment was recorded for [studentUid] - targeted to that
/// student only (no batch broadcast; nobody else should see this).
Future<void> recordFeePaymentNotification(
  Ref ref, {
  required String studentUid,
  required String batchId,
  required double amount,
  required String relatedId,
}) {
  return recordNotificationEvent(
    ref,
    type: NotificationEventType.feePayment,
    batchId: batchId,
    studentUid: studentUid,
    title: 'Payment received',
    body: 'A payment of ₹${amount.toStringAsFixed(0)} was recorded.',
    relatedId: relatedId,
  );
}

/// An announcement is a broadcast event - everyone signed in may see it,
/// so it carries no [batchId]/[studentUid] target.
Future<void> recordAnnouncementNotification(
  Ref ref, {
  required String title,
  required String body,
  required String relatedId,
}) {
  return recordNotificationEvent(
    ref,
    type: NotificationEventType.announcement,
    batchId: null,
    title: title,
    body: body,
    relatedId: relatedId,
  );
}
