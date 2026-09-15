import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/public/data/banner_item.dart';

BannerItem _banner({int sortOrder = 0, bool active = true}) {
  final now = DateTime(2026, 4, 1);
  return BannerItem(
    bannerId: 'banner1',
    imageUrl: 'https://example.com/banner.jpg',
    title: 'Admissions open',
    description: 'Enrol now for 2026-27',
    ctaText: 'Enquire now',
    ctaUrl: 'https://example.com/enquire',
    active: active,
    displayFrom: null,
    displayUntil: null,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('BannerItem (Set 30 - hero carousel ordering)', () {
    test('round-trips through toMap/fromMap, including sortOrder', () {
      final banner = _banner(sortOrder: 3);
      final restored = BannerItem.fromMap(banner.bannerId, banner.toMap());

      expect(restored.sortOrder, 3);
      expect(restored.imageUrl, banner.imageUrl);
      expect(restored.title, banner.title);
      expect(restored.ctaText, banner.ctaText);
      expect(restored.ctaUrl, banner.ctaUrl);
    });

    test(
      'fromMap defaults sortOrder to 0 for a pre-Set-30 document with no sortOrder field',
      () {
        final banner = _banner();
        final map = banner.toMap()..remove('sortOrder');
        final restored = BannerItem.fromMap(banner.bannerId, map);

        expect(restored.sortOrder, 0);
      },
    );

    test('isLive is false when inactive regardless of sortOrder', () {
      final banner = _banner(sortOrder: 1, active: false);
      expect(banner.isLive(DateTime(2026, 4, 2)), isFalse);
    });
  });
}
