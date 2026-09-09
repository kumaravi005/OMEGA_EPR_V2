import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/app.dart';

void main() {
  testWidgets(
    'OmegaApp renders without crashing and falls back to the public home '
    'when Firebase has not been initialized (as in this test environment)',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: OmegaApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Omega Education Centre'), findsWidgets);
      expect(find.text('Sign in'), findsWidgets);
    },
  );
}
