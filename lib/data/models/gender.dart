/// Shared between teacher and student profiles.
enum Gender {
  male,
  female,
  other;

  static Gender fromValue(String value) {
    return Gender.values.firstWhere(
      (gender) => gender.name == value,
      orElse: () => throw ArgumentError('Unknown gender: $value'),
    );
  }
}
