import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { student, admin }

class StudentCredentials {
  const StudentCredentials({
    required this.studentId,
    required this.email,
    required this.username,
    required this.rememberMe,
  });

  final String studentId;
  final String email;
  final String username;
  final bool rememberMe;
}

class AdminCredentials {
  const AdminCredentials({
    required this.facultyUsername,
    required this.rememberMe,
  });

  final String facultyUsername;
  final bool rememberMe;
}

/// Persists login session and optional account identifiers for "Remember Me".
///
/// **Backed by Supabase Auth.** The Supabase client auto-persists the
/// session token in secure storage, so we don't manage the token ourselves.
/// What this class stores locally in [SharedPreferences] is:
///   - a fast "is logged in / what role" hint used by the GoRouter
///     redirect so the first frame can pick the right shell without a
///     network round-trip, and
///   - the optional "Remember Me" account identifier so the next launch can
///     pre-fill the login form. Passwords are never stored locally.
///
/// The actual auth round-trip happens in [signInWithEmail] /
/// [signOutAsUser], which the login screens call through
/// [saveStudentSession] / [saveAdminSession] / [clearSession].
class AuthSessionStorage {
  static const _loggedInKey = 'auth_logged_in';
  static const _roleKey = 'auth_role';
  static const _rememberKey = 'auth_remember';
  static const _lastLoginKey = 'auth_last_login';

  static const _studentIdKey = 'auth_student_id';
  static const _studentEmailKey = 'auth_student_email';
  static const _studentUsernameKey = 'auth_student_username';
  static const _studentPasswordKey = 'auth_student_password';

  static const _adminUsernameKey = 'auth_admin_username';
  static const _adminPasswordKey = 'auth_admin_password';

  SupabaseClient get _supabase => Supabase.instance.client;

  // ── Public API used by the router and the login screens ─────────────

  Future<String> getInitialRoute() async {
    // Always start at /launching. The loader plays the wrench zoom
    // animation, then routes to the right home shell (or /welcome for
    // signed-out users) based on the current auth state. This is the
    // single entry point for every cold start of the app.
    return '/launching';
  }

  /// The Supabase session is the source of truth. A local hint must never
  /// grant access after the secure session has expired or been revoked.
  Future<bool> isLoggedIn() async {
    return _supabase.auth.currentSession != null;
  }

  /// Read the role from the cached local hint. If the hint is missing but
  /// we *do* have a Supabase session, ask the server for the role.
  Future<UserRole?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_roleKey);
    if (cached != null) {
      return switch (cached) {
        'student' => UserRole.student,
        'admin' => UserRole.admin,
        _ => null,
      };
    }

    // No cache. If we have a Supabase session but no role hint, look up
    // the profile to find out what role they are.
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      final role = (row['role'] as String?) ?? 'student';
      await prefs.setString(_roleKey, role);
      return switch (role) {
        'admin' => UserRole.admin,
        _ => UserRole.student,
      };
    } catch (_) {
      // RLS may block the read if the trigger hasn't run yet, or the
      // session is still hydrating. Fall through and return null so the
      // router can bounce the user to /splash instead of /shell.
      return null;
    }
  }

  /// Sign the user in with Supabase Auth, then persist the role hint and
  /// the optional "Remember Me" credentials.
  ///
  /// Students may enter their **PUP email** or, for older demo accounts, a
  /// Student ID plus password. An email is passed to Supabase unchanged;
  /// an ID maps only to the legacy synthetic-email convention.
  ///
  /// We intentionally do not look up a student ID in `profiles` before
  /// authentication. A public lookup endpoint would let anyone enumerate
  /// student IDs and recover their email addresses.
  Future<void> saveStudentSession({
    required String studentId,
    required String email,
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final rawIdentifier = email.isNotEmpty ? email.trim() : studentId.trim();
    final loginIdentifier = studentId.isNotEmpty ? studentId : email;

    // Pick the email to send to Supabase Auth. A PUP webmail is used as-is;
    // a bare student ID supports only the historical synthetic-email demo
    // accounts. New accounts should always sign in with their PUP webmail.
    String derivedEmail;
    if (rawIdentifier.contains('@')) {
      derivedEmail = rawIdentifier.toLowerCase();
    } else {
      derivedEmail = studentAuthEmailFor(rawIdentifier);
    }

    final prefs = await SharedPreferences.getInstance();
    if (!rememberMe) {
      // Even if rememberMe is off, we still sign the user in for this
      // session — but we wipe any previously-saved credentials.
      await _signInOrThrow(email: derivedEmail, password: password);
      await prefs.remove(_rememberKey);
      await _clearStudentFields(prefs);
      await _clearAdminFields(prefs);
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_roleKey, 'student');
      return;
    }

    await _signInOrThrow(email: derivedEmail, password: password);
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_roleKey, 'student');
    await prefs.setBool(_rememberKey, true);
    await prefs.setString(_studentIdKey, loginIdentifier);
    await prefs.setString(_studentEmailKey, derivedEmail);
    await prefs.setString(_studentUsernameKey, username);
    // Remove passwords written by older builds. Keep only the identifier.
    await prefs.remove(_studentPasswordKey);
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
    await _clearAdminFields(prefs);

    // Mirror the student_id / username onto the profiles row so the
    // rest of the app (admin scan, occupancy monitor) can display them.
    if (!loginIdentifier.contains('@')) {
      await _upsertProfile(
        studentId: studentId,
        fullName: username.isNotEmpty ? username : null,
      );
    }
  }

  /// New minimal API: student ID or PUP email plus password. Used by the
  /// 2-field student login form.
  Future<void> signInStudent({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    await saveStudentSession(
      studentId: identifier.contains('@') ? '' : identifier,
      email: identifier.contains('@') ? identifier : '',
      username: '',
      password: password,
      rememberMe: rememberMe,
    );
  }

  /// Convert a PUP student number into the legacy synthetic email, or retain
  /// a PUP email unchanged.
  static String studentAuthEmailFor(String identifier) {
    final cleaned = identifier.trim().toLowerCase();
    if (cleaned.isEmpty) return '';
    if (cleaned.contains('@')) return cleaned;
    return '$cleaned@pupitech.local';
  }

  /// Create a new student account.
  ///
  /// - [studentId] — school-issued number, validated as `YYYY-NNNNN-XX-N`.
  /// - [pupWebmail] — PUP-issued email (`@pup.edu.ph`), used as the
  ///   Supabase auth identity so the student can sign in on any device
  ///   with the same email + password combo.
  /// - [password] — at least 6 characters (Supabase's default minimum).
  /// - [fullName] — optional, derived from the email local-part if blank.
  ///
  /// On success: a row in `auth.users` and (via the `handle_new_user`
  /// trigger) a matching row in `public.profiles` with the student_id
  /// filled in. If email confirmation is disabled in the Supabase
  /// project, the user is also signed in immediately; if confirmation
  /// is required, the response is returned without a session and the
  /// caller is expected to show "check your inbox".
  Future<AuthResponse> signUpStudent({
    required String studentId,
    required String pupWebmail,
    required String password,
    String? fullName,
  }) async {
    final cleanedStudentId = studentId.trim();
    final cleanedEmail = pupWebmail.trim().toLowerCase();
    final derivedName = fullName == null || fullName.trim().isEmpty
        ? cleanedEmail.split('@').first
        : fullName.trim();

    final response = await _supabase.auth.signUp(
      email: cleanedEmail,
      password: password,
      data: {'student_id': cleanedStudentId, 'full_name': derivedName},
    );

    // The trigger does the profile insert. We still write a follow-up
    // upsert in case the trigger was skipped (older deployment) or the
    // profile was created from a manual auth.users import without
    // metadata. Best-effort — a failure here is non-fatal because the
    // user is created either way.
    final user = response.user;
    if (user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': cleanedEmail,
          'student_id': cleanedStudentId,
          'full_name': derivedName,
        });
      } catch (_) {
        // Swallow — the trigger already wrote a row, this is just a
        // safety net for the older schema state.
      }
    }

    return response;
  }

  Future<void> saveAdminSession({
    required String facultyUsername,
    required String password,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // We treat `facultyUsername` as the admin's email for Supabase Auth.
    final email = facultyUsername.contains('@')
        ? facultyUsername
        : '$facultyUsername@pupitech.local';

    if (!rememberMe) {
      await _signInOrThrow(email: email, password: password);
      await _requireAdmin();
      await prefs.remove(_rememberKey);
      await _clearStudentFields(prefs);
      await _clearAdminFields(prefs);
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_roleKey, 'admin');
      return;
    }

    await _signInOrThrow(email: email, password: password);
    await _requireAdmin();
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_roleKey, 'admin');
    await prefs.setBool(_rememberKey, true);
    await prefs.setString(_adminUsernameKey, facultyUsername);
    // Remove passwords written by older builds. Keep only the identifier.
    await prefs.remove(_adminPasswordKey);
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
    await _clearStudentFields(prefs);

    // Roles are assigned only by a protected server-side process, never by
    // the mobile/web client. `_requireAdmin` above verified this account.
  }

  Future<StudentCredentials?> loadStudentCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) return null;

    final studentId = prefs.getString(_studentIdKey);
    final email = prefs.getString(_studentEmailKey);
    final username = prefs.getString(_studentUsernameKey);
    if (studentId == null || email == null || username == null) {
      return null;
    }

    return StudentCredentials(
      studentId: studentId,
      email: email,
      username: username,
      rememberMe: true,
    );
  }

  Future<AdminCredentials?> loadAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) return null;

    final username = prefs.getString(_adminUsernameKey);
    if (username == null) return null;

    return AdminCredentials(facultyUsername: username, rememberMe: true);
  }

  /// Sign the user out of Supabase and clear every local cache.
  Future<void> clearSession() async {
    // Best-effort: drop the row from `active_sessions` so the admin
    // Live tab stops showing this account after they leave. Swallowed
    // on failure so we still proceed to the auth sign-out even if
    // RLS or the network is unhappy.
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.rpc(
          'end_active_session',
          params: {'p_profile_id': user.id, 'p_reason': 'signed_out'},
        );
      }
    } catch (_) {
      // continue
    }
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Even if the network sign-out fails, still nuke the local cache
      // so the next launch boots into /splash.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_rememberKey);
    await prefs.remove(_lastLoginKey);
    await _clearStudentFields(prefs);
    await _clearAdminFields(prefs);
  }

  /// Returns when the user last successfully signed in, or null if we
  /// don't know (first launch, cleared session, etc). Shown on the
  /// "Welcome back" line in the login hero.
  Future<DateTime?> getLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLoginKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Internals ───────────────────────────────────────────────────────

  Future<void> _signInOrThrow({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) {
      throw const AuthException('Sign-in returned no session.');
    }
    // Mirror the trigger on sign-in: the `handle_new_session` trigger
    // only fires on `auth.users` INSERT, so a returning user wouldn't
    // have a row in `active_sessions` until we re-establish it here.
    // Upsert so the call is idempotent — if the row already exists
    // (e.g. a quick sign-out / sign-in cycle), we just refresh the
    // `logged_in_at` and `last_activity_at` timestamps.
    try {
      final user = response.user;
      if (user != null) {
        await _supabase.rpc('start_active_session');
      }
    } catch (_) {
      // Best-effort. The Live tab will just show a missing row for
      // this user until they sign in again, which is non-fatal.
    }
  }

  Future<void> _requireAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const AuthException('No authenticated user.');
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (profile?['role'] == 'admin') return;
    await _supabase.auth.signOut();
    throw const AuthException(
      'This account does not have administrator access.',
    );
  }

  /// Write the student_id / role / name fields back onto the user's
  /// profile row. Triggered on login so admin scan + occupancy screens
  /// see the right names without an extra round-trip later.
  Future<void> _upsertProfile({
    String? studentId,
    String? fullName,
    String? role,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final patch = <String, dynamic>{};
    if (studentId != null) patch['student_id'] = studentId;
    if (fullName != null) patch['full_name'] = fullName;
    if (role != null) patch['role'] = role;
    if (patch.isEmpty) return;
    try {
      await _supabase.from('profiles').update(patch).eq('id', user.id);
    } catch (_) {
      // Profile might not exist yet (auth trigger hasn't run). Try insert.
      try {
        await _supabase.from('profiles').insert({'id': user.id, ...patch});
      } catch (_) {
        // Best-effort. The next successful load will retry.
      }
    }
  }

  Future<void> _clearStudentFields(SharedPreferences prefs) async {
    await prefs.remove(_studentIdKey);
    await prefs.remove(_studentEmailKey);
    await prefs.remove(_studentUsernameKey);
    await prefs.remove(_studentPasswordKey);
  }

  Future<void> _clearAdminFields(SharedPreferences prefs) async {
    await prefs.remove(_adminUsernameKey);
    await prefs.remove(_adminPasswordKey);
  }
}
