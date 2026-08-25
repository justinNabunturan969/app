import 'package:flutter/foundation.dart';
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

  /// Persists the administrator's force-logout reason across restarts so
  /// the login screen can show the REAL reason even if the device was
  /// restarted between the kick and the next launch. One-shot: the login
  /// screen removes it after displaying.
  static const kickReasonKey = 'auth_kick_reason';

  /// One-shot flag set right before the kicked device reloads itself.
  /// The fresh boot reads it in [getInitialRoute] and starts at
  /// `/launching?kicked=1`, so the cold-start animation replays and ends
  /// on the login screen with the admin's reason — no URL gymnastics
  /// needed, this works even if the reload lands on a bare origin.
  static const kickReloadPendingKey = 'auth_kick_reload_pending';

  static const _studentIdKey = 'auth_student_id';
  static const _studentEmailKey = 'auth_student_email';
  static const _studentUsernameKey = 'auth_student_username';
  static const _studentPasswordKey = 'auth_student_password';

  static const _adminUsernameKey = 'auth_admin_username';
  static const _adminPasswordKey = 'auth_admin_password';

  SupabaseClient get _supabase => Supabase.instance.client;

  // ── Public API used by the router and the login screens ─────────────

  Future<String> getInitialRoute() async {
    // Forced-logout replay: the previous session was ended by an admin,
    // and the handler asked for a full reload. Boot straight into the
    // launch route carrying `kicked=1` so the wrench animation plays and
    // LaunchLoader routes to the login screen with the persisted reason.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(kickReloadPendingKey) ?? false) {
        await prefs.remove(kickReloadPendingKey);
        return '/launching?kicked=1';
      }
    } catch (_) {
      // Prefs unavailable — fall through to the normal entry point.
    }

    // Otherwise always start at /launching. The loader plays the wrench
    // zoom animation, then routes to the right home shell (or /welcome for
    // signed-out users) based on the current auth state. This is the
    // single entry point for every cold start of the app.
    return '/launching';
  }

  /// The Supabase session is the source of truth. A local hint must never
  /// grant access after the secure session has expired or been revoked.
  Future<bool> isLoggedIn() async {
    return _supabase.auth.currentSession != null;
  }

  /// Read the user's role.
  ///
  /// The local hint is only a *fallback*. On every call where a Supabase
  /// session exists we re-read the role from `profiles` and overwrite the
  /// cache, so a demoted admin is routed to the student shell on their
  /// very next app start instead of keeping a stale admin shell until
  /// they manually sign out. The cached value is used only when the
  /// network read fails (offline launch) or there is no session yet.
  Future<UserRole?> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    // Always prefer the live value when we have a session.
    final user = _supabase.auth.currentUser;
    if (user != null) {
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
        // device is offline. Fall through to the cached hint below so an
        // offline launch still routes somewhere sensible.
      }
    } else {
      // No session at all — the cached hint must never grant access after
      // the secure session has expired or been revoked.
      await prefs.remove(_roleKey);
      return null;
    }

    final cached = prefs.getString(_roleKey);
    if (cached == null) return null;
    return switch (cached) {
      'student' => UserRole.student,
      'admin' => UserRole.admin,
      _ => null,
    };
  }

  /// Sign the user in with Supabase Auth, then persist the role hint and
  /// the optional "Remember Me" credentials.
  ///
  /// Students may enter their **PUP email** or their Student ID plus
  /// password. An email is passed to Supabase Auth unchanged. A bare ID is
  /// resolved to its real auth email by the `sign_in_identifier` RPC, which
  /// verifies the password server-side before revealing the mapping — so a
  /// student number can never be turned into an email address without
  /// presenting valid credentials.
  Future<void> saveStudentSession({
    required String studentId,
    required String email,
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final rawIdentifier = email.isNotEmpty ? email.trim() : studentId.trim();
    final loginIdentifier = studentId.isNotEmpty ? studentId : email;

    final authEmail = await _resolveAuthEmail(rawIdentifier, password);

    final prefs = await SharedPreferences.getInstance();
    if (!rememberMe) {
      // Even if rememberMe is off, we still sign the user in for this
      // session — but we wipe any previously-saved credentials.
      await _signInOrThrow(email: authEmail, password: password);
      await prefs.remove(_rememberKey);
      await _clearStudentFields(prefs);
      await _clearAdminFields(prefs);
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_roleKey, 'student');
      return;
    }

    await _signInOrThrow(email: authEmail, password: password);
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_roleKey, 'student');
    await prefs.setBool(_rememberKey, true);
    await prefs.setString(_studentIdKey, loginIdentifier);
    await prefs.setString(_studentEmailKey, authEmail);
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

  /// Legacy helper: normalize an identifier, mapping a bare student number
  /// onto the historical synthetic-email convention. Sign-in no longer uses
  /// this — real accounts are resolved server-side via `sign_in_identifier`
  /// — but the mapping still describes how old demo accounts were created.
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

    // The trigger does the profile insert. This write is only a bootstrap
    // for deployments where the trigger missed (older schema state, manual
    // auth.users import). `ignoreDuplicates` makes it a strict no-op when
    // the row already exists, so it can never trip the
    // "Student ID cannot be changed" identity trigger on repeat sign-ups,
    // and any real failure surfaces in the log instead of vanishing.
    final user = response.user;
    if (user != null) {
      try {
        await _supabase.from('profiles').upsert(
          {
            'id': user.id,
            'email': cleanedEmail,
            'student_id': cleanedStudentId,
            'full_name': derivedName,
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
      } catch (e) {
        debugPrint('Profile bootstrap skipped: $e');
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

  /// Map the login identifier onto the Supabase auth email.
  ///
  /// A PUP webmail is used as-is. A bare student ID is resolved through the
  /// `sign_in_identifier` RPC, which verifies the password server-side and
  /// therefore cannot be abused to enumerate who owns which ID. It returns
  /// null (or raises on lockout) for unknown IDs or wrong passwords, both of
  /// which surface to the user as a plain invalid-credentials error.
  Future<String> _resolveAuthEmail(String identifier, String password) async {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();

    final String? resolved;
    try {
      resolved = await _supabase.rpc(
        'sign_in_identifier',
        params: {'p_identifier': trimmed, 'p_password': password},
      );
    } on PostgrestException catch (e) {
      // PGRST202 = "could not find the function" — the server deployment
      // is missing migration 0015. Give the student a working fallback
      // (email sign-in) instead of a generic "not recognized".
      if (e.code == 'PGRST202' ||
          e.message.toLowerCase().contains('could not find the function') ||
          e.message.toLowerCase().contains('sign_in_identifier')) {
        debugPrint('sign_in_identifier RPC missing — run migration 0015.');
        throw const AuthException(
          'Student-ID sign-in is unavailable right now — '
          'please sign in with your PUP email instead.',
        );
      }
      rethrow;
    }
    final email = resolved is String ? resolved.trim().toLowerCase() : '';
    if (email.isEmpty || !email.contains('@')) {
      throw const AuthException('Invalid login credentials');
    }
    return email;
  }

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

  /// Fill the student_id / full_name fields on the user's profile row.
  /// Triggered on login so admin scan + occupancy screens see the right
  /// names without an extra round-trip later.
  ///
  /// Existence is checked first: identity fields are only ever written when
  /// they are still blank, so a normal login can never collide with the
  /// "Student ID cannot be changed" trigger, and the bootstrap insert (for
  /// accounts whose trigger never ran) is backed by the
  /// `profiles_insert_self` policy.
  Future<void> _upsertProfile({
    String? studentId,
    String? fullName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (studentId == null && fullName == null) return;
    try {
      final existing = await _supabase
          .from('profiles')
          .select('student_id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final row = <String, dynamic>{'id': user.id};
        if (user.email != null) row['email'] = user.email;
        if (studentId != null) row['student_id'] = studentId;
        if (fullName != null) row['full_name'] = fullName;
        await _supabase.from('profiles').insert(row);
        return;
      }

      final patch = <String, dynamic>{};
      final currentStudentId = existing['student_id'] as String?;
      final currentFullName = existing['full_name'] as String?;
      if (studentId != null && (currentStudentId == null || currentStudentId.isEmpty)) {
        patch['student_id'] = studentId;
      }
      if (fullName != null && (currentFullName == null || currentFullName.isEmpty)) {
        patch['full_name'] = fullName;
      }
      if (patch.isEmpty) return;
      await _supabase.from('profiles').update(patch).eq('id', user.id);
    } catch (e) {
      debugPrint('Profile sync skipped: $e');
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
