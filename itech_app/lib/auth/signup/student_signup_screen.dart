import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../theme/design_tokens.dart';
import '../validators/auth_validators.dart';
import '../widgets/form_text_field.dart';
import '../widgets/login_hero.dart';
import '../widgets/password_strength_field.dart';

/// "Create Student Account" screen.
///
/// Form fields:
///   - Student ID     (e.g. `2024-08721-MN-0`)
///   - PUP webmail    (e.g. `j.delacruz@iskolarngbayan.pup.edu.ph`)
///   - Password       (≥ 6 chars, with strength meter)
///   - Confirm password
///
/// On submit, the screen calls `AuthSessionStorage.signUpStudent` which:
///   1. `supabase.auth.signUp` — creates the row in `auth.users` and
///      (via the `handle_new_user` trigger) a matching row in
///      `public.profiles` with `student_id` and `full_name` populated
///      from the auth metadata.
///   2. Returns the `AuthResponse`. If a session is present (i.e. the
///      Supabase project's "Confirm email" toggle is off, which is
///      the typical thesis-demo setup), the user is also signed in
///      immediately and we route them straight to the student shell.
///
/// The account lives in Supabase auth, so the same email + password
/// works on any device that talks to the same Supabase project.
class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _studentId = TextEditingController();
  final _pupWebmail = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _lastError;

  @override
  void dispose() {
    _studentId.dispose();
    _pupWebmail.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateConfirm(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please re-type your password to confirm.';
    if (v != _password.text) return 'Passwords do not match.';
    return null;
  }

  /// Humanize the most common Supabase signUp failures so we don't
  /// leak `AuthException` to the student.
  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('already registered') ||
        raw.contains('user already') ||
        raw.contains('duplicate')) {
      return 'An account with that PUP webmail already exists. Try signing in instead.';
    }
    if (raw.contains('email')) {
      return 'That PUP webmail looks invalid. Use the format name@pup.edu.ph.';
    }
    if (raw.contains('password') && raw.contains('short')) {
      return 'Password is too short — use at least 6 characters.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return 'Connection problem. Check your internet and try again.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (raw.contains('weak') || raw.contains('strength')) {
      return 'That password is too weak. Add numbers or a longer phrase.';
    }
    if (kDebugMode) return 'Sign-up failed: $error';
    return "We couldn't create your account. Please double-check the form and try again.";
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _lastError = null;
    });

    try {
      final response = await authSessionStorage.signUpStudent(
        studentId: _studentId.text,
        pupWebmail: _pupWebmail.text,
        password: _password.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.session == null) {
        // Email confirmation is enabled in the Supabase project. The
        // user was created but isn't signed in until they click the
        // link in their inbox. Send them back to the login screen
        // with a clear message.
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: PupColors.cyberAmber,
              content: Text(
                'Account created! Check your PUP inbox to confirm, then sign in.',
                style: const TextStyle(
                  color: Color(0xFF1B1B1B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        context.go('/student/login');
        return;
      }

      // Session returned → user is signed in. Mirror the same hints
      // the login flow sets, so the router redirect picks the right
      // shell on the very first frame.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_logged_in', true);
      await prefs.setString('auth_role', 'student');
      await prefs.setString(
        'auth_last_login',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString('auth_student_id', _studentId.text.trim());
      await prefs.setString(
        'auth_student_email',
        _pupWebmail.text.trim().toLowerCase(),
      );
      await prefs.setString('auth_student_password', _password.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: PupColors.mintGreen,
            content: Text(
              'Welcome, ${_studentId.text.trim()}! Your account is ready.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      context.go('/launching');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = _friendlyAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = _friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? PupColors.darkCard : PupColors.lightCard;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PupColors.ashGray.withValues(alpha: 0.18);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: back arrow + "Already have an account?" link
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to student sign in',
                    onPressed: () => context.go('/student/login'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/student/login'),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Already have an account?'),
                    style: TextButton.styleFrom(
                      foregroundColor: PupColors.brand(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const LoginHero(
                accent: PupColors.techCyan,
                icon: Icons.person_add_alt_1_rounded,
                eyebrow: 'New Student',
                title: 'Create Student Account',
                subtitle:
                    'Sign up with your PUP webmail — you\'ll use the same email and password on any device.',
                tag: 'PUP',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: PupColors.techCyan.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormTextField(
                        controller: _studentId,
                        label: 'Student ID',
                        hint: 'e.g., 2024-08721-MN-0',
                        icon: Icons.credit_card_rounded,
                        validator: AuthValidators.validateStudentId,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),
                      FormTextField(
                        controller: _pupWebmail,
                        label: 'PUP webmail',
                        hint: 'e.g., j.delacruz@iskolarngbayan.pup.edu.ph',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: AuthValidators.validatePupEmail,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),
                      PasswordStrengthField(
                        controller: _password,
                        validator: AuthValidators.validateNewPassword,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),
                      FormTextField(
                        controller: _confirm,
                        label: 'Confirm password',
                        hint: 'Re-type your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: _validateConfirm,
                        textInputAction: TextInputAction.done,
                        enabled: !_loading,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_lastError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _lastError!),
                      ],
                      const SizedBox(height: 18),
                      _PrimaryButton(
                        label: 'Create Account',
                        loading: _loading,
                        accent: PupColors.cyberAmber,
                        foreground: const Color(0xFF1B1B1B),
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Soft reassurance: the account lives in Supabase auth, so
              // it works on any platform that points at the same project.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: PupColors.techCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PupColors.techCyan.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: PupColors.techCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your account is saved in Supabase and works on every device that points at the same project.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: PupColors.accentText(context),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PupColors.signalRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PupColors.signalRed.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: PupColors.signalRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PupColors.signalRed,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.accent,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final Color accent;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          shadowColor: accent.withValues(alpha: 0.55),
        ),
        onPressed: onPressed,
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
