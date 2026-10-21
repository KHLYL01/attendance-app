import 'package:get/get.dart';

class Validator {
  // Validates that a field is not empty
  static String? validateNotEmpty(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '${fieldName.tr} ${'is required'.tr}' : 'This field is required'.tr;
    }
    return null;
  }

  // Validates email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required'.tr;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email'.tr;
    }
    return null;
  }

  // Validates password with common requirements
  static String? validatePassword(
    String? value, {
    int minLength = 8,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireNumbers = false,
    bool requireSpecialChars = false,
  }) {
    if (value == null || value.isEmpty) {
      return 'Password is required'.tr;
    }

    if (value.length < minLength) {
      return 'Password must be at least $minLength characters long'.tr;
    }

    if (requireUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (requireLowercase && !value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (requireNumbers && !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (requireSpecialChars && !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Validates phone number (basic international format)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required'.tr;
    }

    // Basic international phone number validation
    final phoneRegex = RegExp(r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$');

    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number'.tr;
    }

    // You might want to add more specific validation based on your country
    return null;
  }

  // Validates that two fields match (e.g., password confirmation)
  static String? validateMatch(String? value1, String? value2, {String? fieldName}) {
    if (value1 != value2) {
      return fieldName != null ? '$fieldName does not match' : 'Fields do not match';
    }
    return null;
  }

  // Validates numeric input
  static String? validateNumeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return fieldName != null ? '${fieldName.tr} ${'is required'.tr}' : 'This field is required'.tr;
    }

    if (double.tryParse(value) == null) {
      return fieldName != null ? '${fieldName.tr} ${'must be a number'.tr}' : 'Please enter a valid number'.tr;
    }

    return null;
  }

  // Validates minimum length
  static String? validateMinLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.length < minLength) {
      return fieldName != null
          ? '$fieldName must be at least $minLength characters'
          : 'Must be at least $minLength characters';
    }
    return null;
  }

  // Validates maximum length
  static String? validateMaxLength(String? value, int maxLength, {String? fieldName}) {
    if (value != null && value.length > maxLength) {
      return fieldName != null
          ? '$fieldName must be no more than $maxLength characters'
          : 'Must be no more than $maxLength characters';
    }
    return null;
  }
}
