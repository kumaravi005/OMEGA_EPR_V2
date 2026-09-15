import 'package:flutter/material.dart';

/// Brand palette for Omega Education Centre.
///
/// All screens should reference these (or the [ThemeData] built from them
/// in app_theme.dart) instead of hardcoding [Color] values.
abstract final class AppColors {
  static const primary = Color(0xFF1E5AA8);
  static const primaryDark = Color(0xFF143E77);
  static const secondary = Color(0xFF2FA084);

  /// Brand accent sampled from the real Omega logo (branding/logo.png),
  /// same value used for the maskable PWA icon background in Set 28. A
  /// controlled accent only (badges, highlights, splash) - never a
  /// dominant surface color, per Set 29's "do not make the whole app
  /// yellow" direction.
  static const accent = Color(0xFFFFDD00);
  static const onAccent = Color(0xFF1B1F24);

  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1B1F24);
  static const textSecondary = Color(0xFF5B6472);
  static const border = Color(0xFFE1E4E8);

  static const error = Color(0xFFD64545);
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A324);
}
