import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../biometric_authenticator.dart';
import '../session/auth_session_storage.dart';
import '../../theme/design_tokens.dart';
import '../validators/auth_validators.dart';
import '../widgets/biometric_button.dart';
import '../widgets/form_text_field.dart';
import '../widgets/login_hero.dart';
import '../widgets/password_strength_field.dart';

/// Faculty / Admin login — distinct, security-forward hero
/// (pup-maroon / shield), same shared form widgets, symmetrical
/// "switch to student" link, and consistent biometric row.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _facultyUsername = TextEditingController();
  final _password = TextEditingController();

  bool _rememberMe = true;
  bool _loading = false;
  String? _lastError;
  String? _rememberedUser;
  final _biometricAuthenticator = BiometricAuthenticator();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await authSessionStorage.loadAdminCredentials();
    if (!mounted || saved == null) return;

    setState(() {
      _facultyUsername.text = saved.facultyUsername;
      _rememberMe = saved.rememberMe;
      _rememberedUser = saved.facultyUsername.isNotEmpty
          ? saved.facultyUsername[0].toUpperCase() +
                saved.facultyUsername.substring(1)
          : null;
    });
  }

  @override
  void dispose() {
    _facultyUsername.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Convert a Supabase [AuthException] into a one-line message safe for
  /// end users. Same mapping as the student login so both screens speak
  /// the same language.
  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_grant')) {
      return 'Wrong username or password.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Please confirm your email first — check your inbox.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return 'Connection problem. Check your internet and try again.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    const setupHint =
        'Confirm this account exists and is confirmed in '
        'Supabase Authentication.';
    if (kDebugMode) return 'Unable to sign in: $error. $setupHint';
    return 'Unable to sign in. $setupHint';
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
      await authSessionStorage.saveAdminSession(
        facultyUsername: _facultyUsername.text.trim(),
        password: _password.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/admin/shell');
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

  Future<void> _unlockWithBiometrics() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _lastError = null;
    });

    final biometricError = await _biometricAuthenticator.authenticate();
    if (biometricError != null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _lastError = biometricError;
        });
      }
      return;
    }

    final hasSession = await authSessionStorage.isLoggedIn();
    final role = hasSession ? await authSessionStorage.getRole() : null;
    if (!mounted) return;
    if (role == UserRole.admin) {
      setState(() => _loading = false);
      context.go('/admin/shell');
      return;
    }
    setState(() {
      _loading = false;
      _lastError = hasSession
          ? 'This saved session does not have administrator access.'
          : 'Sign in with your password once on this device before using fingerprint sign-in.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? PupColors.darkCard : PupColors.lightCard;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PupColors.ashGray.withValues(alpha: 0.18);

    final greetingTitle = _rememberedUser != null
        ? 'Welcome back, $_rememberedUser'
        : 'Faculty / Admin';
    final greetingSub = _rememberedUser != null
        ? 'Your account is remembered. Enter your password to continue.'
        : 'Sign in with your faculty credentials to manage equipment.';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: back arrow + role-switch link
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.go('/role'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/student/login'),
                    icon: const Icon(Icons.school_outlined, size: 16),
                    label: const Text('Student Login'),
                    style: TextButton.styleFrom(
                      foregroundColor: PupColors.techCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LoginHero(
                accent: PupColors.pupMaroon,
                icon: Icons.shield_rounded,
                eyebrow: 'Faculty Access',
                title: greetingTitle,
                subtitle: greetingSub,
                tag: 'ADMIN',
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
                      color: PupColors.pupMaroon.withValues(alpha: 0.10),
                      blurRadius: 20,
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
                        controller: _facultyUsername,
                        label: 'Faculty username or email',
                        hint: 'e.g., admin1@pup.edu.ph',
                        icon: Icons.shield_outlined,
                        validator: AuthValidators.validateFacultyUsername,
                      ),
                      const SizedBox(height: 12),
                      PasswordStrengthField(
                        controller: _password,
                        validator: AuthValidators.validatePassword,
                      ),
                      const SizedBox(height: 6),
                      _RememberAndForgot(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? true),
                        onForgot: _showForgotPasswordDialog,
                      ),
                      if (_lastError != null) ...[
                        const SizedBox(height: 12),
                        _AdminErrorBanner(message: _lastError!),
                      ],
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        label: 'Login',
                        loading: _loading,
                        accent: PupColors.pupMaroon,
                        foreground: Colors.white,
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Symmetrical "or continue with" + biometric row
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : PupColors.ashGray.withValues(alpha: 0.30),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : PupColors.ashGray,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : PupColors.ashGray.withValues(alpha: 0.30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BiometricLoginRow(
                onBiometric: _unlockWithBiometrics,
                onScan: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final controller = TextEditingController(text: _facultyUsername.text);
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset admin password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Faculty email',
              hintText: 'e.g., admin@pup.edu.ph',
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              return email.contains('@') ? null : 'Enter your faculty email.';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  controller.text.trim().toLowerCase(),
                  redirectTo: 'pupitech://reset-callback',
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'If the account exists, a reset link was sent.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } on AuthException catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Reset failed: ${error.message}')),
                );
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _RememberAndForgot extends StatelessWidget {
  const _RememberAndForgot({
    required this.value,
    required this.onChanged,
    required this.onForgot,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Future<void> Function(BuildContext) onForgot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PupColors.slateGray;
    return Row(
      children: [
        SizedBox(
          height: 32,
          width: 32,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: PupColors.cyberAmber,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Remember me',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => onForgot(context),
          style: TextButton.styleFrom(
            foregroundColor: PupColors.techCyan,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
      ],
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
            side: BorderSide(
              color: PupColors.cyberAmber.withValues(alpha: 0.55),
              width: 1.0,
            ),
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
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

/// Inline error banner for the admin login — same shape as the student
/// one but tinted with the maroon admin accent so the user knows which
/// screen the error belongs to.
class _AdminErrorBanner extends StatelessWidget {
  const _AdminErrorBanner({required this.message});

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
