import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/widgets/empty_view.dart';
import 'package:omega_epr_v2/core/widgets/error_view.dart';
import 'package:omega_epr_v2/core/widgets/loading_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('LoadingView shows a spinner and optional message', (tester) async {
    await tester.pumpWidget(wrap(const LoadingView(message: 'Loading data')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading data'), findsOneWidget);
  });

  testWidgets('ErrorView shows the message and a retry button when provided', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      wrap(ErrorView(message: 'Something went wrong', onRetry: () => retried = true)),
    );

    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('EmptyView shows its message', (tester) async {
    await tester.pumpWidget(wrap(const EmptyView(message: 'Nothing here yet')));

    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
