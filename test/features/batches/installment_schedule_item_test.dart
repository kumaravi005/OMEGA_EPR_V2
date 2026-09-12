import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/validators.dart';
import 'package:omega_epr_v2/features/batches/data/installment_schedule_item.dart';

void main() {
  test('InstallmentScheduleItem round-trips through toMap/fromMap', () {
    final item = InstallmentScheduleItem(
      label: 'Admission',
      amount: 2000,
      dueDate: DateTime(2026, 4, 10),
      status: InstallmentStatus.pending,
    );

    final restored = InstallmentScheduleItem.fromMap(item.toMap());

    expect(restored.label, 'Admission');
    expect(restored.amount, 2000);
    expect(restored.dueDate, DateTime(2026, 4, 10));
    expect(restored.status, InstallmentStatus.pending);
    expect(restored.status.label, 'Pending');
  });

  test(
    'InstallmentStatus round-trips by name and rejects an unknown value',
    () {
      expect(InstallmentStatus.fromValue('paid'), InstallmentStatus.paid);
      expect(InstallmentStatus.paid.label, 'Paid');
      expect(() => InstallmentStatus.fromValue('overdue'), throwsArgumentError);
    },
  );

  group(
    'installment amount validation (Validators.amount, allowZero: false)',
    () {
      test('rejects a zero or negative installment amount', () {
        expect(
          Validators.amount('0', label: 'Installment amount', allowZero: false),
          isNotNull,
        );
        expect(
          Validators.amount(
            '-100',
            label: 'Installment amount',
            allowZero: false,
          ),
          isNotNull,
        );
      });

      test('accepts a valid positive installment amount', () {
        expect(
          Validators.amount(
            '2000',
            label: 'Installment amount',
            allowZero: false,
          ),
          isNull,
        );
      });
    },
  );
}
