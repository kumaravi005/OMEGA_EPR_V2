import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/report_templates/data/report_layout_template.dart';

void main() {
  group('ReportLayoutTemplate.toBranding', () {
    test('hides an element from the baked branding when its show flag is off, even if text is set', () {
      final template = ReportLayoutTemplate(
        templateId: 't1',
        name: 'Letterhead',
        header: const ReportHeaderConfig(
          instituteName: 'Omega Education Centre',
          showInstituteName: true,
          tagline: 'Excellence in learning',
          showTagline: false, // typed but hidden
        ),
        footer: const ReportFooterConfig(),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final branding = template.toBranding();
      expect(branding.header.instituteName, 'Omega Education Centre');
      expect(branding.header.tagline, isNull);
    });

    test('treats an empty string as hidden even when the show flag is on', () {
      final template = ReportLayoutTemplate(
        templateId: 't1',
        name: 'Letterhead',
        header: const ReportHeaderConfig(address: '', showAddress: true),
        footer: const ReportFooterConfig(),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(template.toBranding().header.address, isNull);
    });

    test('carries the logo placement fractions through unchanged', () {
      final template = ReportLayoutTemplate(
        templateId: 't1',
        name: 'Letterhead',
        header: const ReportHeaderConfig(
          logoUrl: 'https://example.org/logo.png',
          logoXFraction: 0.7,
          logoYFraction: 0.2,
          logoWidthFraction: 0.25,
        ),
        footer: const ReportFooterConfig(),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final placement = template.toBranding().header.logoPlacement;
      expect(placement.xFraction, 0.7);
      expect(placement.yFraction, 0.2);
      expect(placement.widthFraction, 0.25);
    });

    test('round-trips through toMap/fromMap', () {
      final original = ReportLayoutTemplate(
        templateId: 't1',
        name: 'Letterhead',
        header: const ReportHeaderConfig(instituteName: 'Omega', showTagline: false, logoXFraction: 0.4),
        footer: const ReportFooterConfig(showSignature: true, signatureLabel: 'Principal'),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final map = original.toMap();
      final restored = ReportLayoutTemplate.fromMap('t1', {
        ...map,
        // Simulate Firestore round-tripping Timestamp objects: toMap already
        // produced Timestamps, so pass them straight through.
      });

      expect(restored.name, original.name);
      expect(restored.header.instituteName, original.header.instituteName);
      expect(restored.header.showTagline, false);
      expect(restored.header.logoXFraction, 0.4);
      expect(restored.footer.showSignature, true);
      expect(restored.footer.signatureLabel, 'Principal');
    });
  });
}
