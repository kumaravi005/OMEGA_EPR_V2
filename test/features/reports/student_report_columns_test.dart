import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/reports/data/student_report_columns.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';

StudentProfile _student() {
  final now = DateTime(2026, 1, 1);
  return StudentProfile(
    uid: 'student1',
    accountId: 'stu001',
    admissionNumber: 'STU0001',
    name: 'Test Student',
    fatherName: 'Test Father',
    dateOfBirth: DateTime(2010, 6, 15),
    gender: Gender.female,
    address: '123 Main St',
    className: 'Class 9',
    board: 'CBSE',
    batchId: 'batch1',
    academicSession: '2026-27',
    academicSessionId: 'session1',
    classId: 'class9',
    primaryMobile: '9876543210',
    secondaryMobile: '9876500000',
    standardFee: 12000,
    finalFee: 10000,
    feeReason: 'Sibling discount',
    paymentPlan: PaymentPlan.installment,
    admissionDate: now,
    currentAdmissionId: 'admission1',
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('StudentReportColumns (Set 20 additions)', () {
    test('admissionNumber, address, dateOfBirth, gender, standardFee all render', () {
      final row = StudentReportRow(
        student: _student(),
        batchName: 'Morning Batch',
        paid: 4000,
        due: 6000,
      );
      final keys = ['admissionNumber', 'address', 'dateOfBirth', 'gender', 'standardFee'];

      final cells = StudentReportColumns.row(row, keys);

      expect(cells[0], 'STU0001');
      expect(cells[1], '123 Main St');
      expect(cells[2], '2010-06-15');
      expect(cells[3], 'Female');
      expect(cells[4], 'Rs. 12000');
    });

    test('admissionNumber renders as "-" when blank (pre-Set-11 record)', () {
      final blank = StudentProfile(
        uid: 'student2',
        accountId: 'stu002',
        admissionNumber: '',
        name: 'No Admission Number',
        fatherName: 'Father',
        dateOfBirth: DateTime(2010, 1, 1),
        gender: Gender.male,
        address: 'Address',
        className: 'Class 9',
        board: 'CBSE',
        batchId: 'batch1',
        academicSession: '2026-27',
        academicSessionId: 'session1',
        classId: 'class9',
        primaryMobile: '9876543210',
        secondaryMobile: null,
        standardFee: 9000,
        finalFee: 9000,
        feeReason: null,
        paymentPlan: PaymentPlan.monthly,
        admissionDate: DateTime(2026, 1, 1),
        currentAdmissionId: '',
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final row = StudentReportRow(student: blank, batchName: 'Batch', paid: 0, due: 9000);

      expect(StudentReportColumns.row(row, ['admissionNumber']), ['-']);
    });

    test('orderedKeys always returns catalogue order, not selection order', () {
      final selected = {'due', 'name', 'finalFee'};
      expect(
        StudentReportColumns.orderedKeys(selected),
        ['name', 'finalFee', 'due'],
      );
    });

    test('due renders Paid in full / Due / Advance correctly', () {
      final student = _student();
      expect(
        StudentReportColumns.row(
          StudentReportRow(student: student, batchName: 'B', paid: 10000, due: 0),
          ['due'],
        ),
        ['Paid in full'],
      );
      expect(
        StudentReportColumns.row(
          StudentReportRow(student: student, batchName: 'B', paid: 6000, due: 4000),
          ['due'],
        ),
        ['Due Rs. 4000'],
      );
      expect(
        StudentReportColumns.row(
          StudentReportRow(student: student, batchName: 'B', paid: 10500, due: -500),
          ['due'],
        ),
        ['Advance Rs. 500'],
      );
    });
  });
}
