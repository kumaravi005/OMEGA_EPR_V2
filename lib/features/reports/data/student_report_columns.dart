import '../../../core/utils/date_key.dart';
import '../../student/data/student_profile.dart';
import '../presentation/widgets/column_picker.dart';

/// One student's data, resolved once (name/fee fields from [StudentProfile]
/// plus [paid]/[due] computed from their combined payment history - Set
/// 19's `feePayments` ledger plus any legacy history - and [batchName]
/// resolved from the batch catalogue) - the row shape `StudentExportScreen`
/// (Set 20's general "Student Data Export") builds. The Set 19 fee-status-
/// aware report (Paid/Partially Paid/Due/Overdue, installment-aware) is a
/// separate screen, `FeeDueReportScreen`, built on `StudentFeeSummary`
/// instead - see docs/database-architecture.md's "Reports & Exports
/// (Set 20)" for why these stayed two purpose-built screens rather than
/// one screen trying to do both.
class StudentReportRow {
  const StudentReportRow({
    required this.student,
    required this.batchName,
    required this.paid,
    required this.due,
  });

  final StudentProfile student;
  final String batchName;
  final double paid;
  final double due;
}

/// The column catalogue `StudentExportScreen` picks from - "admin decides
/// which columns appear" (Set 20 section 2).
abstract final class StudentReportColumns {
  static const all = [
    ColumnOption('admissionNumber', 'Admission number'),
    ColumnOption('name', 'Name'),
    ColumnOption('fatherName', 'Father name'),
    ColumnOption('accountId', 'Account ID'),
    ColumnOption('className', 'Class'),
    ColumnOption('board', 'Board'),
    ColumnOption('batchName', 'Batch'),
    ColumnOption('academicSession', 'Session'),
    ColumnOption('primaryMobile', 'Primary mobile'),
    ColumnOption('secondaryMobile', 'Secondary mobile'),
    ColumnOption('address', 'Address'),
    ColumnOption('dateOfBirth', 'Date of birth'),
    ColumnOption('gender', 'Gender'),
    ColumnOption('standardFee', 'Standard fee'),
    ColumnOption('finalFee', 'Final fee'),
    ColumnOption('paid', 'Paid'),
    ColumnOption('due', 'Due'),
  ];

  static const defaultStudentExportKeys = {
    'admissionNumber',
    'name',
    'fatherName',
    'className',
    'board',
    'primaryMobile',
    'secondaryMobile',
    'finalFee',
    'paid',
    'due',
  };

  /// [orderedKeys] in catalogue order (not selection order), so the
  /// printed column order is always predictable regardless of the order
  /// the admin happened to tap the chips in.
  static List<String> orderedKeys(Set<String> selectedKeys) => [
    for (final column in all)
      if (selectedKeys.contains(column.key)) column.key,
  ];

  static List<String> row(StudentReportRow data, List<String> orderedKeys) {
    return [for (final key in orderedKeys) _cell(data, key)];
  }

  static String _cell(StudentReportRow data, String key) {
    final student = data.student;
    switch (key) {
      case 'admissionNumber':
        return student.admissionNumber.isEmpty ? '-' : student.admissionNumber;
      case 'name':
        return student.name;
      case 'fatherName':
        return student.fatherName;
      case 'accountId':
        return student.accountId;
      case 'className':
        return student.className;
      case 'board':
        return student.board;
      case 'batchName':
        return data.batchName;
      case 'academicSession':
        return student.academicSession;
      case 'primaryMobile':
        return student.primaryMobile;
      case 'secondaryMobile':
        return student.secondaryMobile ?? '-';
      case 'address':
        return student.address;
      case 'dateOfBirth':
        return dateKey(student.dateOfBirth);
      case 'gender':
        return switch (student.gender.name) {
          'male' => 'Male',
          'female' => 'Female',
          _ => 'Other',
        };
      case 'standardFee':
        return 'Rs. ${student.standardFee.toStringAsFixed(0)}';
      case 'finalFee':
        return 'Rs. ${student.finalFee.toStringAsFixed(0)}';
      case 'paid':
        return 'Rs. ${data.paid.toStringAsFixed(0)}';
      case 'due':
        if (data.due > 0) return 'Due Rs. ${data.due.toStringAsFixed(0)}';
        if (data.due < 0) {
          return 'Advance Rs. ${(-data.due).toStringAsFixed(0)}';
        }
        return 'Paid in full';
      default:
        return '';
    }
  }
}
