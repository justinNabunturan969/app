import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { student, admin }

class StudentCredentials {
  const StudentCredentials({
    required this.studentId,
    required this.email,
    required this.username,
    required this.password,
    required this.rememberMe,
  });

  final String studentId;
  final String email;
  final String username;
  final String password;
  final bool rememberMe;
}

class AdminCredentials {
  const AdminCredentials({
    required this.facultyUsername,
    required this.password,
    required this.rememberMe,
  });

  final String facultyUsername;
  final String password;
  final bool rememberMe;
}

/// Persists login session and optional credentials for "Remember Me".
///
/// **Backed by Supabase Auth.** The Supabase client auto-persists the
/// session token in secure storage, so we don't manage the token ourselves.
/// What this class stores locally in [SharedPreferences] is:
///   - a fast "is logged in / what role" hint used by the GoRouter
///     redirect so the first frame can pick the right shell without a
///     network round-trip, and
///   - the optional "Remember Me" credentials (email/username + password)
///     so the next launch can pre-fill the login form.
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
    if (!await isLoggedIn()) return '/splash';

    final role = await getRole();
    return switch (role) {
      UserRole.student => '/student/shell',
      UserRole.admin => '/admin/shell',
      null => '/splash',
    };
  }

  /// True if Supabase has a valid session, OR a previously-cached local
  /// hint says we're logged in. The Supabase check is the source of
  /// truth — the local cache is just a fast path for app start.
  Future<bool> isLoggedIn() async {
    if (_supabase.auth.currentSession != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
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
  /// Students only enter their **Student ID + Password** in the form. We
  /// derive the auth email internally (`<student-id>@pupitech.local`) so the
  /// Supabase Auth call always has the right shape. The pre-refactor API
  /// took a separate email + username field; that information is preserved
  /// in the profiles table instead.
  Future<void> saveStudentSession({
    required String studentId,
    required String email,
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final derivedEmail = _deriveStudentEmail(studentId, email);
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
    await prefs.setString(_studentIdKey, studentId);
    await prefs.setString(_studentEmailKey, derivedEmail);
    await prefs.setString(_studentUsernameKey, username);
    await prefs.setString(_studentPasswordKey, password);
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
    await _clearAdminFields(prefs);

    // Mirror the student_id / username onto the profiles row so the
    // rest of the app (admin scan, occupancy monitor) can display them.
    await _upsertProfile(
      studentId: studentId,
      fullName: username.isNotEmpty ? username : null,
    );
  }

  /// New minimal API: just student ID + password. Used by the
  /// 2-field student login form.
  Future<void> signInStudent({
    required String studentId,
    required String password,
    required bool rememberMe,
  }) async {
    await saveStudentSession(
      studentId: studentId,
      email: '', // derived from studentId
      username: '',
      password: password,
      rememberMe: rememberMe,
    );
  }

  /// Convert a PUP student number into the synthetic email Supabase Auth
  /// uses internally. e.g. `2024-08721-MN-0` → `2024-08721-mn-0@pupitech.local`.
  static String _deriveStudentEmail(String studentId, String fallback) {
    final cleaned = studentId.trim().toLowerCase();
    if (cleaned.isEmpty) return fallback;
    if (cleaned.contains('@')) return cleaned;
    return '$cleaned@pupitech.local';
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
      await prefs.remove(_rememberKey);
      await _clearStudentFields(prefs);
      await _clearAdminFields(prefs);
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_roleKey, 'admin');
      return;
    }

    await _signInOrThrow(email: email, password: password);
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_roleKey, 'admin');
    await prefs.setBool(_rememberKey, true);
    await prefs.setString(_adminUsernameKey, facultyUsername);
    await prefs.setString(_adminPasswordKey, password);
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
    await _clearStudentFields(prefs);

    // Ensure the profile row is marked as admin so RLS policies let
    // the admin screens read everything.
    await _upsertProfile(role: 'admin');
  }

  Future<StudentCredentials?> loadStudentCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) return null;

    final studentId = prefs.getString(_studentIdKey);
    final email = prefs.getString(_studentEmailKey);
    final username = prefs.getString(_studentUsernameKey);
    final password = prefs.getString(_studentPasswordKey);
    if (studentId == null ||
        email == null ||
        username == null ||
        password == null) {
      return null;
    }

    return StudentCredentials(
      studentId: studentId,
      email: email,
      username: username,
      password: password,
      rememberMe: true,
    );
  }

  Future<AdminCredentials?> loadAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) return null;

    final username = prefs.getString(_adminUsernameKey);
    final password = prefs.getString(_adminPasswordKey);
    if (username == null || password == null) return null;

    return AdminCredentials(
      facultyUsername: username,
      password: password,
      rememberMe: true,
    );
  }

  /// Sign the user out of Supabase and clear every local cache.
  Future<void> clearSession() async {
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
        await _supabase.from('profiles').insert({
          'id': user.id,
          ...patch,
        });
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
