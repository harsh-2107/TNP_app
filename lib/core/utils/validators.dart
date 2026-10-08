import '../extensions/string_extensions.dart';

/// Reusable form validators, wired directly into `TextFormField.validator`.
class Validators {
  const Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? collegeEmail(String? value) {
    final requiredError = required(value, field: 'College email');
    if (requiredError != null) return requiredError;
    if (!value!.isValidEmail) return 'Enter a valid email address.';
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, field: 'Email');
    if (requiredError != null) return requiredError;
    if (!value!.isValidEmail) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    final requiredError = required(value, field: 'Password');
    if (requiredError != null) return requiredError;
    if (value!.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredError = required(value, field: 'Phone number');
    if (requiredError != null) return requiredError;
    if (!value!.isValidIndianPhone) return 'Enter a valid 10-digit phone number.';
    return null;
  }

  /// Combine multiple validators; returns the first non-null error.
  static String? Function(String?) compose(List<String? Function(String?)> validators) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
