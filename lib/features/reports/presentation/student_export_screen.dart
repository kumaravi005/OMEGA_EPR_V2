import 'package:flutter/material.dart';
import '../data/report_template.dart';
import '../data/student_report_columns.dart';
import 'student_report_export_screen.dart';

/// Admin export of the full/filtered student list. See
/// [StudentReportExportScreen] for the shared implementation.
class StudentExportScreen extends StatelessWidget {
  const StudentExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentReportExportScreen(
      appBarTitle: 'Student export',
      module: ReportModule.studentExport,
      datasetTitle: 'Student List',
      exportFileName: 'student_list',
      defaultColumns: StudentReportColumns.defaultStudentExportKeys,
    );
  }
}
