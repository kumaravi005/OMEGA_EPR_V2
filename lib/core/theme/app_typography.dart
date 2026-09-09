import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Text style scale used to build the app's [TextTheme].
abstract final class AppTypography {
  static const _base = TextStyle(color: AppColors.textPrimary);

  static final headlineLarge = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700);
  static final headlineMedium = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final titleLarge = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final bodyLarge = _base.copyWith(fontSize: 16);
  static final bodyMedium = _base.copyWith(fontSize: 14);
  static final bodySmall = _base.copyWith(fontSize: 12, color: AppColors.textSecondary);
  static final label = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
