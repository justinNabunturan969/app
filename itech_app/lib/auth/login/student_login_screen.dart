import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../env/supabase_config.dart';
import '../../theme/design_tokens.dart';
import '../session/auth_session_storage.dart';
import '../validators/auth_validators.dart';
import '../widgets/form_text_field.dart';
import '../widgets/login_hero.dart';
import '../widgets/password_strength_field.dart';

/// Student login — friendly hero (tech-cyan / school), inline validation,
/// password strength meter, and a dynamic "Welcome back" greeting when
/// credentials are remembered.
class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _studentId = TextEditingController();
  final _password = TextEditingController();

  bool _rememberMe = true;
  bool _loading = false;
  String? _lastError;
  String? _rememberedName;
  DateTime? _lastLogin;

  /// Feedback for the server-side sign-in rate limiter
  /// (`sign_in_rate_limit`, see migrations 0018/0019). After a failed
  /// attempt we ask the server how many tries remain; when the account is
  /// locked we run a live countdown until the lockout expires.
  static const int _maxSignInAttempts = 5;
  int? _attemptsLeft;
  DateTime? _lockedUntil;
  String? _lockCountdown;
  Timer? _lockTicker;

  /// How long a remembered credential stays "fresh" enough to be
  /// auto-applied on the next launch. Past this window, the personalised
  /// "Welcome back" greeting is suppressed and the student ID field is
  /// cleared so a shared device doesn't leak the previous user's
  /// identifier to whoever picks up the browser next.
  /// Set to 7 days — long enough that a student who signs in once a
  /// week still gets the convenience, short enough that an abandoned
  /// lab login doesn't pin a name to a machine indefinitely.
  static const Duration _kRememberMeFreshness = Duration(days: 7);

  /// Set when the app was returned here by an administrator force
  /// logout (`kicked=1`). Holds the reason the admin provided, or a
  /// default wording when none was given. Persists across refreshes —
  /// it is only cleared once the user actually signs in again.
  String? _kickMessage;
  bool _kickLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-checked on every dependency change: the kick can navigate here
    // while the screen is already open (same route, new query param), so
    // a one-shot flag would miss it.
    final kicked =
        GoRouterState.of(context).uri.queryParameters['kicked'] == '1';
    if (kicked && _kickMessage == null && !_kickLoading) {
      _kickLoading = true;
      unawaited(_loadKickMessage());
    }
  }

  /// The reason was persisted by the forced-logout handler BEFORE the
  /// session was dropped, so it survives any number of restarts. It is
  /// deliberately KEPT here (not consumed) so a refresh never blanks the
  /// banner; [_submit] clears it after a successful sign-in.
  Future<void> _loadKickMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final reason =
        prefs.getString(AuthSessionStorage.kickReasonKey) ??
        'Your session was ended by an administrator.';
    if (!mounted) return;
    setState(() => _kickMessage = reason);
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await authSessionStorage.loadStudentCredentials();
    final lastLogin = await authSessionStorage.getLastLogin();
    if (!mounted || saved == null) return;

    // "Welcome back, <name>" is a credential-stuffing head start on a
    // shared device — anyone who picks up the browser sees the previous
    // user's first name AND has the student ID pre-filled, and only
    // needs to guess the password. Suppress the personalised greeting
    // (and the pre-filled ID) when the saved login is older than
    // [_kRememberMeFreshness]. After that window the identifier is
    // forgotten, forcing the next user to re-type the student ID from
    // their own memory. The "Remember me" checkbox stays checked so
    // the *next* legitimate sign-in still gets remembered.
    final shouldPersonalize = lastLogin == null ||
        DateTime.now().difference(lastLogin) < _kRememberMeFreshness;

    setState(() {
      _studentId.text = shouldPersonalize ? saved.studentId : '';
      _rememberMe = saved.rememberMe;
      _lastLogin = lastLogin;
      // The username is the "short" form (e.g. juandelacruz); we surface
      // it capitalized in the welcome back greeting.
      _rememberedName = (shouldPersonalize && saved.username.isNotEmpty)
          ? saved.username[0].toUpperCase() + saved.username.substring(1)
          : null;
    });
  }

  /// Human-readable "3h ago" / "yesterday" / "Mar 12" string.
  static String _formatRelative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${when.month}/${when.day}';
  }

  @override
  void dispose() {
    _lockTicker?.cancel();
    _studentId.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Convert a Supabase [AuthException] into a one-line message that's
  /// safe to show to end users. We never want to leak the raw server
  /// wording (which can hint at user enumeration).
  ///
  /// Every "we don't recognize this identifier" server error — wrong
  /// password, unknown email, unknown student ID — is collapsed onto the
  /// same generic wording so an attacker probing a list of student IDs
  /// or emails can't tell which ones are real.
  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('student-id sign-in is unavailable')) {
      return 'Student-ID sign-in is unavailable right now. '
          'Sign in with your PUP email instead.';
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_grant') ||
        raw.contains('user not found') ||
        raw.contains('no user') ||
        raw.contains('invalid email or password')) {
      return 'Wrong student ID or password.';
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
      _attemptsLeft = null;
    });

    try {
      await authSessionStorage.signInStudent(
        identifier: _studentId.text.trim(),
        password: _password.text,
        rememberMe: _rememberMe,
      );
      // Fresh, successful sign-in — any previous force-logout notice is
      // resolved, so the banner won't reappear on the next visit.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AuthSessionStorage.kickReasonKey);
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/launching');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = _friendlyAuthError(e);
      });
      unawaited(_refreshRateLimitStatus());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = _friendlyAuthError(e);
      });
      unawaited(_refreshRateLimitStatus());
    }
  }

  /// Ask the server (migration 0037) whether the *source IP* is currently
  /// locked. We deliberately do NOT call `sign_in_attempt_status` here
  /// anymore — as of 0037 that RPC requires an authenticated session, and
  /// we are by definition unauthenticated at this point. The IP-level
  /// status is the more useful feedback in a shared-lab deployment: a
  /// student who just hit a wrong password should learn whether the
  /// classroom's egress IP is in a 15-min cooldown, not whether their own
  /// identifier has 3 tries left. The per-identifier counter still
  /// exists server-side; it just isn't surfaced here any more, which also
  /// closes the user-enumeration oracle the old RPC exposed to `anon`.
  /// Best-effort: any RPC failure leaves the plain error in place.
  Future<void> _refreshRateLimitStatus() async {
    try {
      final res = await Supabase.instance.client.rpc('sign_in_ip_status');
      if (res is! Map || !mounted) return;
      final data = Map<String, dynamic>.from(res);

      final untilRaw = data['locked_until'] as String?;
      if (untilRaw != null) {
        final until = DateTime.tryParse(untilRaw)?.toLocal();
        if (until != null && until.isAfter(DateTime.now())) {
          _startLockCountdown(until);
        }
      }
      // The IP lockout is the only signal we surface from here. Per-
      // identifier counters live behind an authenticated RPC now and
      // aren't visible to anon callers.
    } catch (_) {
      // Feedback is optional — never let it mask the real auth error.
    }
  }

  /// Tick once per second until [until], then clear the lock state so the
  /// Login button re-enables and the countdown banner disappears.
  void _startLockCountdown(DateTime until) {
    _lockTicker?.cancel();
    setState(() {
      _lockedUntil = until;
      _lockCountdown = _formatCountdown(until);
    });
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _lockTicker?.cancel();
        return;
      }
      final remaining = until.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _lockTicker?.cancel();
        setState(() {
          _lockedUntil = null;
          _lockCountdown = null;
        });
      } else {
        setState(() => _lockCountdown = _formatCountdown(until));
      }
    });
  }

  static String _formatCountdown(DateTime until) {
    final remaining = until.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    // Supabase emails the reset link, so we need a real address. A bare
    // student ID cannot be translated here — resolving ID -> email requires
    // proving the password (see sign_in_identifier), which a student who
    // forgot theirs obviously cannot do. Ask for the PUP webmail instead.
    final controller = TextEditingController(
      text: _studentId.text.contains('@') ? _studentId.text.trim() : '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'PUP webmail',
              hintText: 'e.g., student1@pup.edu.ph',
              helperText:
                  'Enter the PUP email you registered with, not your '
                  'student ID.',
            ),
            validator: AuthValidators.validatePupEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  controller.text.trim().toLowerCase(),
                  redirectTo: SupabaseConfig.passwordResetRedirectUrl,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'If that account exists, a reset link was sent.',
                    ),
                  ),
                );
              } on AuthException catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Reset failed: ${e.message}')),
                );
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? PupColors.darkCard : PupColors.lightCard;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PupColors.ashGray.withValues(alpha: 0.18);

    final greetingTitle = _rememberedName != null
        ? 'Welcome back, $_rememberedName'
        : 'Student Sign In';
    final lastLoginSuffix = _lastLogin != null
        ? ' • Last login ${_formatRelative(_lastLogin!)}'
        : '';
    final greetingSub = _rememberedName != null
        ? 'Your account is remembered. Enter your password to continue.$lastLoginSuffix'
        : 'Use your PUP credentials to borrow and return equipment.';

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
                    tooltip: 'Back to role selection',
                    onPressed: () => context.go('/role'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/admin/login'),
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Faculty / Admin'),
                    style: TextButton.styleFrom(
                      foregroundColor: PupColors.brand(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LoginHero(
                accent: PupColors.techCyan,
                icon: Icons.school_rounded,
                eyebrow: 'Student Access',
                title: greetingTitle,
                subtitle: greetingSub,
                tag: 'PUP',
              ),
              const SizedBox(height: 18),
              if (_kickMessage != null) ...[
                _KickedBanner(message: _kickMessage!),
                const SizedBox(height: 14),
              ],
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
                        label: 'Student ID or PUP email',
                        hint: 'e.g., 2024-08721-MN-0 or student1@pup.edu.ph',
                        icon: Icons.credit_card_rounded,
                        validator: AuthValidators.validateStudentLogin,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      PasswordStrengthField(
                        controller: _password,
                        validator: AuthValidators.validatePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
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
                        _ErrorBanner(message: _lastError!),
                      ],
                      if (_lockCountdown != null) ...[
                        const SizedBox(height: 12),
                        _LockoutBanner(countdown: _lockCountdown!),
                      ] else if (_attemptsLeft != null &&
                          _attemptsLeft! > 0) ...[
                        const SizedBox(height: 12),
                        _AttemptsLeftBanner(
                          attemptsLeft: _attemptsLeft!,
                          maxAttempts: _maxSignInAttempts,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        label: 'Login',
                        loading: _loading,
                        accent: PupColors.cyberAmber,
                        foreground: const Color(0xFF1B1B1B),
                        onPressed: (_loading || _lockedUntil != null)
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 10),
                      // Inline link to the sign-up flow so a brand-new
                      // student doesn't have to back out to /role to
                      // find the "Create account" entry point.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : PupColors.ashGray,
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/student/signup'),
                            style: TextButton.styleFrom(
                              foregroundColor: PupColors.accentText(context),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Create one',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner shown on the login screen when an administrator force-logged
/// this device out. Amber "security notice" tone — distinct from the
/// red credential-error banner below the form.
class _KickedBanner extends StatelessWidget {
  const _KickedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PupColors.cyberAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PupColors.cyberAmber.withValues(alpha: 0.55),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            color: PupColors.amberText(context),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed out by an administrator',
                  style: TextStyle(
                    color: PupColors.amberText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: PupColors.amberText(context).withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            foregroundColor: PupColors.accentText(context),
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

/// Inline error banner shown under the login form when auth fails.
/// Uses a small warning icon and a signal-red accent so it doesn't
/// get confused with the green check-mark next to valid fields.
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

/// Amber hint shown after a wrong-credential attempt telling the student
/// how many tries remain before the server locks the account.
class _AttemptsLeftBanner extends StatelessWidget {
  const _AttemptsLeftBanner({
    required this.attemptsLeft,
    required this.maxAttempts,
  });

  final int attemptsLeft;
  final int maxAttempts;

  @override
  Widget build(BuildContext context) {
    final plural = attemptsLeft == 1 ? 'attempt' : 'attempts';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PupColors.cyberAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PupColors.cyberAmber.withValues(alpha: 0.55),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: PupColors.amberText(context),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$attemptsLeft of $maxAttempts $plural left before your '
              'account is temporarily locked for 5 minutes.',
              style: TextStyle(
                color: PupColors.amberText(context),
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

/// Red lockout banner with a LIVE countdown ("Try again in 4:32").
/// The [countdown] string is refreshed every second by the parent state
/// while the lockout is active; the Login button is disabled meanwhile.
class _LockoutBanner extends StatelessWidget {
  const _LockoutBanner({required this.countdown});

  final String countdown;

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
            Icons.timer_outlined,
            color: PupColors.signalRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Too many failed attempts. Try again in $countdown.',
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
