import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/theme/app_colors.dart';
import 'package:omega_epr_v2/features/academics/data/academics_repositories.dart';
import 'package:omega_epr_v2/features/public/data/advertisement.dart';
import 'package:omega_epr_v2/features/public/data/public_content_repositories.dart';
import 'package:omega_epr_v2/features/public/presentation/ad_popup.dart';

Advertisement _ad({
  String? buttonText = 'join now',
  String? buttonUrl,
  AdButtonAction? buttonAction,
}) {
  final now = DateTime(2026, 9, 1);
  return Advertisement(
    advertisementId: 'ad1',
    posterUrl: 'https://example.com/poster.jpg',
    title: 'admission open',
    description: null,
    buttonText: buttonText,
    buttonUrl: buttonUrl,
    buttonAction: buttonAction,
    active: true,
    startDate: null,
    endDate: null,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _app(Advertisement ad) {
  return ProviderScope(
    overrides: [
      activeAdvertisementsProvider.overrideWith((ref) => Stream.value([ad])),
      activeSchoolClassesProvider.overrideWith((ref) => Stream.value(const [])),
      activeBoardsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: const MaterialApp(home: Scaffold(body: AdPopupTrigger())),
  );
}

void main() {
  group('Advertisement.resolvedButtonAction', () {
    test('an explicit action wins', () {
      expect(
        _ad(buttonAction: AdButtonAction.callback).resolvedButtonAction,
        AdButtonAction.callback,
      );
      expect(
        _ad(
          buttonAction: AdButtonAction.link,
          buttonUrl: 'https://example.com',
        ).resolvedButtonAction,
        AdButtonAction.link,
      );
    });

    test('an old ad with no action and no link opens the enquiry form', () {
      expect(_ad().resolvedButtonAction, AdButtonAction.enquiry);
    });

    test('an old ad with a link keeps opening that link', () {
      expect(
        _ad(buttonUrl: 'https://example.com').resolvedButtonAction,
        AdButtonAction.link,
      );
    });

    test('a link action with no URL falls back to the enquiry form', () {
      expect(
        _ad(buttonAction: AdButtonAction.link).resolvedButtonAction,
        AdButtonAction.enquiry,
      );
      expect(
        _ad(
          buttonAction: AdButtonAction.link,
          buttonUrl: '  ',
        ).resolvedButtonAction,
        AdButtonAction.enquiry,
      );
    });

    test(
      'round-trips through toMap/fromMap, and tolerates a missing field',
      () {
        final ad = _ad(buttonAction: AdButtonAction.callback);
        final restored = Advertisement.fromMap(ad.id, ad.toMap());
        expect(restored.buttonAction, AdButtonAction.callback);

        final legacy = ad.toMap()..remove('buttonAction');
        expect(Advertisement.fromMap(ad.id, legacy).buttonAction, isNull);
      },
    );
  });

  group('ad popup button', () {
    testWidgets('is an enabled, solid brand-blue button', (tester) async {
      await tester.pumpWidget(_app(_ad()));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
      expect(
        button.style!.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.primary,
      );
      expect(find.text('join now'), findsOneWidget);
    });

    testWidgets('closes the popup and opens the Admission enquiry form', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_ad()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('join now'));
      await tester.pumpAndSettle();

      expect(find.text('admission open'), findsNothing);
      expect(find.text('Admission enquiry'), findsOneWidget);
    });

    testWidgets('opens the callback form when the ad says so', (tester) async {
      await tester.pumpWidget(_app(_ad(buttonAction: AdButtonAction.callback)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('join now'));
      await tester.pumpAndSettle();

      expect(find.text('Request a callback'), findsOneWidget);
    });

    testWidgets('shows no button when the ad has no button text', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_ad(buttonText: null)));
      await tester.pumpAndSettle();

      expect(find.text('admission open'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
