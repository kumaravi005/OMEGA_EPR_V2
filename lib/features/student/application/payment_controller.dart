import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../auth/application/auth_providers.dart';
import '../data/payment.dart';
import '../data/student_repository.dart';

class PaymentFailure implements Exception {
  const PaymentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final paymentControllerProvider = Provider<PaymentController>(
  (ref) => PaymentController(ref),
);

class PaymentController {
  PaymentController(this._ref);

  final Ref _ref;

  Future<void> recordPayment({
    required String studentUid,
    required String batchId,
    required double amount,
    required DateTime date,
    required PaymentMode mode,
    required String? remark,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const PaymentFailure(
        'Could not record the payment. Please sign in again.',
      );
    }

    try {
      final id = await _ref
          .read(paymentRepositoryProvider(studentUid))
          .add(
            Payment(
              paymentId: '',
              amount: amount,
              date: date,
              mode: mode,
              remark: remark?.trim(),
              createdAt: DateTime.now(),
              createdBy: admin.uid,
            ),
          );
      await recordFeePaymentNotification(
        _ref,
        studentUid: studentUid,
        batchId: batchId,
        amount: amount,
        relatedId: id,
      );
    } catch (_) {
      throw const PaymentFailure(
        'Could not record the payment. Please try again.',
      );
    }
  }
}
