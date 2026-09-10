import '../../student/data/student_profile.dart';
import '../presentation/widgets/column_picker.dart';

/// One student's data, resolved once (name/fee fields from [StudentProfile]
/// plus [paid]/[due] computed from their payment history and [batchName]
/// resolved from the batch catalogue) - shared by the student-list export
/// and the fee-dues export, which differ only in filters/defaults, not in
/// what a "student row" contains.
class StudentReportRow {
  const StudentReportRow({required this.student, required this.batchName, required this.paid, required this.due});

  final StudentProfile student;
  final String batchName;
  final double paid;
  final double due;
}

/// The shared column catalogue both student-shaped exports (student list,
/// fee dues) pick from - "admin decides which columns appear" is
/// implemented once here, not per screen.
abstract final class StudentReportColumns {
  static const all = [
    ColumnOption('name', 'Name'),
    ColumnOption('fatherName', 'Father name'),
    ColumnOption('accountId', 'Account ID'),
    ColumnOption('className', 'Class'),
    ColumnOption('board', 'Board'),
    ColumnOption('batchName', 'Batch'),
    ColumnOption('academicSession', 'Session'),
    ColumnOption('primaryMobile', 'Primary mobile'),
    ColumnOption('secondaryMobile', 'Secondary mobile'),
    ColumnOption('finalFee', 'Final fee'),
    ColumnOption('paid', 'Paid'),
    ColumnOption('due', 'Due'),
  ];

  static const defaultStudentExportKeys = {
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

  static const defaultFeeDuesKeys = {'name', 'fatherName', 'className', 'primaryMobile', 'secondaryMobile', 'due'};

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
      case 'finalFee':
        return 'Rs. ${student.finalFee.toStringAsFixed(0)}';
      case 'paid':
        return 'Rs. ${data.paid.toStringAsFixed(0)}';
      case 'due':
        if (data.due > 0) return 'Due Rs. ${data.due.toStringAsFixed(0)}';
        if (data.due < 0) return 'Advance Rs. ${(-data.due).toStringAsFixed(0)}';
        return 'Paid in full';
      default:
        return '';
    }
  }
}
