import 'package:url_launcher/url_launcher.dart';

/// Pure URI builders, kept separate from the actual platform launch calls
/// below so the number-formatting logic can be unit tested without
/// mocking a platform channel.
Uri buildTelUri(String phoneNumber) => Uri(scheme: 'tel', path: phoneNumber);

Uri buildWhatsAppUri(String phoneNumber) {
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri.parse('https://wa.me/$digitsOnly');
}

/// Opens the device's native phone dialer with [phoneNumber] pre-filled.
/// Does not place the call itself - the user still has to press call.
Future<bool> callNumber(String phoneNumber) => launchUrl(buildTelUri(phoneNumber));

/// Opens WhatsApp (app or web, whichever the platform supports) with a
/// chat to [phoneNumber] ready to send. [phoneNumber] should include the
/// country code (no leading "+" or spaces needed - non-digits are
/// stripped).
Future<bool> openWhatsApp(String phoneNumber) {
  return launchUrl(buildWhatsAppUri(phoneNumber), mode: LaunchMode.externalApplication);
}
