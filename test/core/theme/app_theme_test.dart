import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/theme/app_colors.dart';
import 'package:omega_epr_v2/core/theme/app_theme.dart';

void main() {
  test('AppTheme.light uses Material 3 and the brand primary color', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
