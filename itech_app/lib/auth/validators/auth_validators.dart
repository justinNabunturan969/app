import 'package:flutter/foundation.dart';

class AuthValidators {
  static String? validateStudentId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Student ID is required.';

    // Strict format: YYYY-XXXXX-XX-X
    // Example: 2024-08721-MN-0
    final re = RegExp(r'^\d{4}-\d{5}-[A-Za-z]{2}-\d{1}$');
    if (!re.hasMatch(v)) {
      return 'Invalid format. Expected YYYY-XXXXX-XX-X (e.g., 2024-08721-MN-0).';
    }
    return null;
  }

  static String? validatePupEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'PUP email is required.';

    final re = RegExp(r'^[^\s@]+@pup\.edu\.ph$');
    if (!re.hasMatch(v)) return 'Email must end with @pup.edu.ph.';
    return null;
  }

  static String? validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required.';

    if (v.length < 5) return 'Username must be at least 5 characters.';

    final re = RegExp(r'^[A-Za-z0-9_]+$');
    if (!re.hasMatch(v)) {
      return 'Username can contain only alphanumeric characters and underscores.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  static String? validateFacultyUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Faculty username is required.';
    if (v.length < 5) return 'Faculty username must be at least 5 characters.';
    return null;
  }

  @visibleForTesting
  static bool isValidStudentId(String value) =>
      validateStudentId(value) == null;
}
