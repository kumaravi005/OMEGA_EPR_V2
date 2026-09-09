/// Reusable form-field validators for use with `TextFormField.validator`.
abstract final class Validators {
  static String? required(String? value, {String message = 'This field is required'}) {
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
}
