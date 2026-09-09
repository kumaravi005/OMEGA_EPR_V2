import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/contact_actions.dart';

void main() {
  group('buildTelUri', () {
    test('builds a tel: URI with the raw phone number', () {
      final uri = buildTelUri('9999999999');
      expect(uri.scheme, 'tel');
      expect(uri.path, '9999999999');
    });
  });

  group('buildWhatsAppUri', () {
    test('strips non-digit characters before building the wa.me link', () {
      final uri = buildWhatsAppUri('+91 99999-99999');
      expect(uri.toString(), 'https://wa.me/919999999999');
    });

    test('leaves a plain digit string untouched', () {
      final uri = buildWhatsAppUri('919999999999');
      expect(uri.toString(), 'https://wa.me/919999999999');
    });
  });
}
