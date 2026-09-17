import 'package:flutter/material.dart';

/// Brand palette for Omega Education Centre.
///
/// All screens should reference these (or the [ThemeData] built from them
/// in app_theme.dart) instead of hardcoding [Color] values.
abstract final class AppColors {
  /// Exact brand tokens per the landing-page design brief (post-Set-33) -
  /// refined from earlier sets' values by a couple of RGB units each, kept
  /// as the single app-wide source so every screen (not just the public
  /// site) stays on the same brand color.
  static const primary = Color(0xFF1E57A6);
  static const primaryDark = Color(0xFF163F7D);
  static const secondary = Color(0xFF2FA084);

  /// Brand accent sampled from the real Omega logo (branding/logo.png),
  /// same value used for the maskable PWA icon background in Set 28. A
  /// controlled accent only (badges, highlights, splash) - never a
  /// dominant surface color, per Set 29's "do not make the whole app
  /// yellow" direction.
  static const accent = Color(0xFFFFDB00);
  static const onAccent = Color(0xFF16181B);

  static const background = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);

  /// Sunken/well surface for chips and placeholders - a shade darker than
  /// [background], used to give a chip depth against the page itself.
  static const surfaceSunken = Color(0xFFEEF1F7);

  static const textPrimary = Color(0xFF16181B);
  static const textSecondary = Color(0xFF63666B);
  static const border = Color(0xFFE3E7EF);

  static const error = Color(0xFFD64545);
  static const success = Color(0xFF146B40);
  static const successSoft = Color(0xFFE5F6EC);
  static const warning = Color(0xFFE0A324);
}
