import 'package:flutter/material.dart';
import '../data/report_template.dart';
import '../data/student_report_columns.dart';
import 'student_report_export_screen.dart';

/// Admin export of student fee dues, meant to be printed and handed to
/// staff for manual calling (no telecaller account exists in this
/// project). See [StudentReportExportScreen] for the shared
/// implementation this and [StudentExportScreen] both build on.
class FeeDuesExportScreen extends StatelessWidget {
  const FeeDuesExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentReportExportScreen(
      appBarTitle: 'Fee dues export',
      module: ReportModule.feeDuesExport,
      datasetTitle: 'Fee Dues Report',
      exportFileName: 'fee_dues',
      defaultColumns: StudentReportColumns.defaultFeeDuesKeys,
      defaultSortKey: StudentSortKey.due,
      defaultSortAscending: false,
      showDuesOnlyFilter: true,
    );
  }
}
