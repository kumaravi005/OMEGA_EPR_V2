import '../../../core/utils/date_key.dart';
import '../../fees/data/fee_calculator.dart';
import '../../student/data/student_admission.dart';
import '../../student/data/student_profile.dart';
import '../presentation/widgets/column_picker.dart';

/// One student's fee position for the Fee Due Report (Set 20 sections
/// 4-5) - built directly from Set 19's [StudentFeeSummary] (via
/// `FeeDueReportScreen`), never recalculated with a new formula. Combines
/// both the "dedicated fee dues report" (section 4: session/class/batch/
/// board/status filters) and the "telecaller/staff print report"
/// (section 5: a column-configurable contact list) into ONE report,
/// since both are the same underlying data with a different column
/// selection - see docs/database-architecture.md's "Reports & Exports
/// (Set 20)" for why this wasn't built as two competing screens.
class FeeReportRow {
  const FeeReportRow({
    required this.student,
    required this.admission,
    required this.batchName,
    required this.totalPaid,
    required this.balanceDue,
    required this.status,
    required this.lastPaymentDate,
  });

  final StudentProfile student;
  final StudentAdmission? admission;
  final String batchName;
  final double totalPaid;
  final double balanceDue;
  final FeeStatus? status;
  final DateTime? lastPaymentDate;
}

abstract final class FeeReportColumns {
  static const all = [
    ColumnOption('admissionNumber', 'Admission number'),
    ColumnOption('name', 'Student name'),
    ColumnOption('fatherName', 'Father name'),
    ColumnOption('className', 'Class'),
    ColumnOption('batchName', 'Batch'),
    ColumnOption('board', 'Board'),
    ColumnOption('academicSession', 'Session'),
    ColumnOption('primaryMobile', 'Primary contact'),
    ColumnOption('secondaryMobile', 'Secondary contact'),
    ColumnOption('standardFee', 'Standard fee'),
    ColumnOption('finalFee', 'Final fee'),
    ColumnOption('paid', 'Paid'),
    ColumnOption('due', 'Due'),
    ColumnOption('status', 'Status'),
    ColumnOption('lastPaymentDate', 'Last payment date'),
    ColumnOption('remark', 'Remark'),
  ];

  /// Section 4's "dedicated fee dues report" shape.
  static const defaultFeeDueKeys = {
    'name',
    'fatherName',
    'className',
    'batchName',
    'finalFee',
    'paid',
    'due',
    'status',
  };

  /// Section 5's "telecaller/staff print report" shape - the same report,
  /// a different column selection, so it's offered as a one-tap preset
  /// rather than a second screen.
  static const defaultStaffContactKeys = {
    'name',
    'fatherName',
    'className',
    'batchName',
    'board',
    'primaryMobile',
    'secondaryMobile',
    'finalFee',
    'paid',
    'due',
    'lastPaymentDate',
    'remark',
  };

  static List<String> orderedKeys(Set<String> selectedKeys) => [
    for (final column in all)
      if (selectedKeys.contains(column.key)) column.key,
  ];

  static List<String> row(FeeReportRow data, List<String> orderedKeys) {
    return [for (final key in orderedKeys) _cell(data, key)];
  }

  static String _cell(FeeReportRow data, String key) {
    final student = data.student;
    switch (key) {
      case 'admissionNumber':
        return student.admissionNumber.isEmpty ? '-' : student.admissionNumber;
      case 'name':
        return student.name;
      case 'fatherName':
        return student.fatherName;
      case 'className':
        return student.className;
      case 'batchName':
        return data.batchName;
      case 'board':
        return student.board;
      case 'academicSession':
        return student.academicSession;
      case 'primaryMobile':
        return student.primaryMobile;
      case 'secondaryMobile':
        return student.secondaryMobile ?? '-';
      case 'standardFee':
        return data.admission == null
            ? '-'
            : 'Rs. ${data.admission!.standardFee.toStringAsFixed(0)}';
      case 'finalFee':
        return data.admission == null
            ? '-'
            : 'Rs. ${data.admission!.finalFee.toStringAsFixed(0)}';
      case 'paid':
        return 'Rs. ${data.totalPaid.toStringAsFixed(0)}';
      case 'due':
        if (data.balanceDue > 0) return 'Rs. ${data.balanceDue.toStringAsFixed(0)}';
        if (data.balanceDue < 0) {
          return 'Advance Rs. ${(-data.balanceDue).toStringAsFixed(0)}';
        }
        return 'Paid in full';
      case 'status':
        return data.status?.label ?? '-';
      case 'lastPaymentDate':
        return data.lastPaymentDate == null ? '-' : dateKey(data.lastPaymentDate!);
      case 'remark':
        return data.admission?.feeReason ?? '-';
      default:
        return '';
    }
  }
}
