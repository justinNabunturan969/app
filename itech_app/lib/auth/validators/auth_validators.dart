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

  /// Students may authenticate with their school ID or their PUP email.
  static String? validateStudentLogin(String? value) {
    final v = value?.trim() ?? '';
    if (v.contains('@')) return validatePupEmail(v);
    return validateStudentId(v);
  }

  static String? validatePupEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'PUP email is required.';

    // PUP-issued addresses can use a subdomain, for example
    // `name@iskolarngbayan.pup.edu.ph`. The former exact-domain pattern
    // rejected the address shown in the sign-up UI itself.
    final re = RegExp(r'^[^\s@]+@(?:[A-Za-z0-9-]+\.)*pup\.edu\.ph$');
    if (!re.hasMatch(v)) return 'Email must use a pup.edu.ph address.';
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

  /// Login / password-reset forms: accepts the historical minimum so
  /// existing accounts created under the old 6-char policy can still sign
  /// in. Do NOT tighten this — use [validateNewPassword] when a password
  /// is being CREATED or reset.
  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    // Supabase Auth's default minimum is six characters.
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// Password creation (sign-up, reset): stricter than the login check.
  /// Existing short accounts keep working; only NEW passwords must meet
  /// the stronger bar. Also enable "Leaked password protection" in the
  /// Supabase dashboard (Authentication -> Policies) for HaveIBeenPwned
  /// checks server-side — see SUPABASE_SETUP.md.
  ///
  /// Requirements: at least 8 characters, at least one capital letter,
  /// at least one special character, and at least three numbers.
  static String? validateNewPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Use at least one capital letter.';
    }
    if (RegExp(r'\d').allMatches(v).length < 3) {
      return 'Use at least three numbers.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      return 'Use at least one special character.';
    }
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
