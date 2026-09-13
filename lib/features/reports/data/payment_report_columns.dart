import '../../../core/utils/date_key.dart';
import '../../fees/data/fee_payment.dart';
import '../presentation/widgets/column_picker.dart';

/// One payment row for the Payment Report (Set 20 section 6) - built
/// directly from Set 19's [FeePayment], with display names resolved once
/// (student/class/batch/collected-by) rather than re-deriving anything
/// about the payment itself. Reversed payments are included exactly like
/// active ones - "reversed payments must remain visible with their
/// status... do not delete or hide historical payment records simply
/// because they were reversed" (section 6).
class PaymentReportRow {
  const PaymentReportRow({
    required this.payment,
    required this.studentName,
    required this.admissionNumber,
    required this.className,
    required this.batchName,
    required this.collectedByName,
  });

  final FeePayment payment;
  final String studentName;
  final String admissionNumber;
  final String className;
  final String batchName;
  final String collectedByName;
}

abstract final class PaymentReportColumns {
  static const all = [
    ColumnOption('paymentNumber', 'Payment number'),
    ColumnOption('studentName', 'Student'),
    ColumnOption('admissionNumber', 'Admission number'),
    ColumnOption('className', 'Class'),
    ColumnOption('batchName', 'Batch'),
    ColumnOption('paymentDate', 'Payment date'),
    ColumnOption('amount', 'Amount'),
    ColumnOption('mode', 'Payment mode'),
    ColumnOption('referenceNumber', 'Reference number'),
    ColumnOption('status', 'Status'),
    ColumnOption('collectedBy', 'Collected by'),
  ];

  static const defaultKeys = {
    'paymentNumber',
    'studentName',
    'className',
    'batchName',
    'paymentDate',
    'amount',
    'mode',
    'status',
  };

  static List<String> orderedKeys(Set<String> selectedKeys) => [
    for (final column in all)
      if (selectedKeys.contains(column.key)) column.key,
  ];

  static List<String> row(PaymentReportRow data, List<String> orderedKeys) {
    return [for (final key in orderedKeys) _cell(data, key)];
  }

  static String _cell(PaymentReportRow data, String key) {
    final payment = data.payment;
    switch (key) {
      case 'paymentNumber':
        return payment.paymentNumber;
      case 'studentName':
        return data.studentName;
      case 'admissionNumber':
        return data.admissionNumber.isEmpty ? '-' : data.admissionNumber;
      case 'className':
        return data.className;
      case 'batchName':
        return data.batchName;
      case 'paymentDate':
        return dateKey(payment.paymentDate);
      case 'amount':
        return 'Rs. ${payment.amount.toStringAsFixed(0)}';
      case 'mode':
        return payment.mode.label;
      case 'referenceNumber':
        return payment.referenceNumber ?? '-';
      case 'status':
        return payment.isReversed ? 'Reversed' : 'Active';
      case 'collectedBy':
        return data.collectedByName;
      default:
        return '';
    }
  }
}
