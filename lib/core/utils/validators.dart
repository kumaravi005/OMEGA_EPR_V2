/// Reusable form-field validators for use with `TextFormField.validator`.
abstract final class Validators {
  static String? required(
    String? value, {
    String message = 'This field is required',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, message: 'Email is required');
    if (requiredError != null) return requiredError;

    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!pattern.hasMatch(value!.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Accepts a plain 10-digit Indian mobile number, optionally with a
  /// `+91`/`0` prefix, spaces, or dashes - checked by digit count after
  /// stripping formatting, not a specific pattern, so `98765 43210`,
  /// `+91-9876543210` and `9876543210` all pass. [isRequired] false skips
  /// the empty-value check (for an optional secondary number) while still
  /// validating its format if the admin did type one in.
  static String? phone(
    String? value, {
    bool isRequired = true,
    String label = 'Phone number',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? '$label is required' : null;
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    // 10 digits (plain mobile), 11 (leading 0), or 12 (country code 91).
    if (digitsOnly.length < 10 || digitsOnly.length > 12) {
      return 'Enter a valid $label';
    }
    return null;
  }
}
