import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/theme/app_theme.dart';
import 'package:omega_epr_v2/core/widgets/app_button.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('AppButton shows its label and invokes onPressed when tapped', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(AppButton(label: 'Save', onPressed: () => tapped = true)),
    );

    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('AppButton is disabled while isLoading', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        AppButton(
          label: 'Save',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();

    expect(tapped, isFalse);
  });
}
