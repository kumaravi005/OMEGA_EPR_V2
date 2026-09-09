import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/app.dart';

void main() {
  testWidgets(
    'OmegaApp renders without crashing and surfaces a graceful error '
    'when Firebase has not been initialized (as in this test environment)',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: OmegaApp()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Unable to reach authentication service'), findsOneWidget);
    },
  );
}
