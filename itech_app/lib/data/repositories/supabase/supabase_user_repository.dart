import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../user_repository.dart';

/// Supabase-backed profile repository. Reads the row in `public.profiles`
/// for the currently-authenticated user, and the `active_sessions` table
/// for the live-occupancy feed.
class SupabaseUserRepository implements UserRepository {
  const SupabaseUserRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  String? get currentAuthId => _client.auth.currentUser?.id;

  @override
  Future<UserProfile> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'SupabaseUserRepository.getCurrentUser called with no signed-in user.',
      );
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile(
      studentId: (row['student_id'] as String?) ?? '',
      studentName:
          (row['full_name'] as String?) ??
          (row['email'] as String?) ??
          'Student',
      studentEmail: (row['email'] as String?) ?? user.email ?? '',
      studentProgram: (row['program'] as String?) ?? '',
      studentYearLevel: (row['year_level'] as String?) ?? '',
      studentSection: (row['section'] as String?) ?? '',
      memberSince:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<void> updateCurrentProfile({
    required String fullName,
    required String program,
    required String yearLevel,
    required String section,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('You are no longer signed in.');
    await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'program': program.trim(),
          'year_level': yearLevel.trim(),
          'section': section.trim(),
        })
        .eq('id', user.id);
  }

  /// Pulls the live-occupancy feed from Supabase. RLS lets admins see
  /// every row (`is_admin()` true) and students see only their own
  /// (`profile_id = auth.uid()`), so the controller can call this
  /// unconditionally from the admin shell without a manual filter.
  ///
  /// We join `profiles` for the student's name and `equipment` (via
  /// `current_equipment_id`) so the admin's Live tab shows the same
  /// `ActiveSession` shape the UI already knows how to render.
  @override
  Future<List<ActiveSession>> getActiveSessions() async {
    // The server records any abandoned session in the audit history before
    // removing it. A short heartbeat window handles browsers that close
    // before their final pagehide request can finish.
    try {
      await _client.rpc('expire_stale_sessions');
    } catch (_) {
      // Students are not allowed to run the admin-only sweep; their own
      // query below remains correctly RLS-scoped.
    }
    return _readActiveSessions();
  }

  /// Subscribes to the underlying table, then reloads the joined view used by
  /// the UI. `stream()` only returns columns of `active_sessions`; re-reading
  /// on each change preserves the profile and equipment details shown by the
  /// Live tab.
  @override
  Stream<List<ActiveSession>> watchActiveSessions() {
    if (_client.auth.currentUser == null) return const Stream.empty();
    return _client
        .from('active_sessions')
        .stream(primaryKey: ['profile_id'])
        .asyncMap((_) => _readActiveSessions());
  }

  Future<List<ActiveSession>> _readActiveSessions() async {
    final rows = await _client
        .from('active_sessions')
        .select(
          'profile_id, logged_in_at, last_activity_at, activity, '
          'current_equipment_id, '
          'profiles:profile_id ( student_id, full_name, email, program ), '
          'equipment:current_equipment_id ( id, name, location )',
        )
        .gte(
          'last_activity_at',
          // 5-minute client filter. The server's `expire_stale_sessions`
          // (matching 5-minute window in migration 0009) is the source of
          // truth; this just keeps the in-memory list from being filled
          // with rows the server has already swept. Loosened from 2 min
          // because mobile browsers throttle background timers, so a
          // student who briefly backgrounded the app can come back
          // without their row being invisible to the admin.
          DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        )
        .order('last_activity_at', ascending: false);

    return rows.map<ActiveSession>(_fromRow).toList(growable: false);
  }

  static ActiveSession _fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final equipment = row['equipment'] as Map<String, dynamic>?;
    final profileId = row['profile_id'] as String;

    return ActiveSession(
      // We use the auth profile id as the session id since the table
      // has a 1-row-per-user primary key on `profile_id`. The
      // controller's `kickSession` deletes by this id.
      id: profileId,
      studentId: (profile?['student_id'] as String?) ?? profileId,
      studentName:
          (profile?['full_name'] as String?) ??
          (profile?['email'] as String?) ??
          'Student',
      program: (profile?['program'] as String?) ?? '',
      equipmentName: (equipment?['name'] as String?) ?? '— no equipment —',
      equipmentId: (equipment?['id'] as String?) ?? '',
      location: (equipment?['location'] as String?) ?? '',
      loginAt:
          DateTime.tryParse((row['logged_in_at'] as String?) ?? '') ??
          DateTime.now(),
      lastActivityAt:
          DateTime.tryParse((row['last_activity_at'] as String?) ?? '') ??
          DateTime.now(),
      activity: _parseActivity((row['activity'] as String?) ?? 'active'),
    );
  }

  static SessionActivity _parseActivity(String raw) {
    switch (raw) {
      case 'idle':
        return SessionActivity.idle;
      case 'returning':
        return SessionActivity.returning;
      case 'active':
      default:
        return SessionActivity.active;
    }
  }

  /// Removes the current user's row from `active_sessions` so the
  /// Live tab stops showing them after they sign out (or after the
  /// app is backgrounded / closed). Errors are rethrown so the
  /// controller can surface them in the UI — silently swallowing
  /// them left the "Go offline" toggle looking like a no-op.
  @override
  Future<void> removeOwnSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.rpc(
      'end_active_session',
      params: {'p_profile_id': user.id, 'p_reason': 'closed'},
    );
  }

  /// Re-registers the current user's `active_sessions` row.
  ///
  /// We call `start_active_session` (not `touch_active_session`) because
  /// the function is now an upsert: on insert it sets both timestamps
  /// and `activity = 'active'`; on conflict it only refreshes
  /// `last_activity_at` and `activity`, leaving `logged_in_at` alone so
  /// the admin's "Logged in Xm ago" display stays accurate. Critically,
  /// the upsert means a missing row (e.g. cleaned up by
  /// `expire_stale_sessions` after a long background) is re-created on
  /// the very next heartbeat — without this, a returning student would
  /// stay invisible on the Live tab until they signed out and back in.
  ///
  /// Called on app launch (in `SessionLifecycleGuard.initState`) and on
  /// the 30-second heartbeat, so a user who briefly backgrounded the
  /// app reappears on the admin's Live tab as soon as they come back.
  ///
  /// Errors are rethrown so the controller can show them to the user.
  /// The previous `catch (_) {}` silently swallowed every failure,
  /// which made "tap the toggle, nothing happens" impossible to
  /// diagnose from the UI.
  @override
  Future<void> markOwnSessionActive() async {
    await _client.rpc('start_active_session');
  }

  /// Admin-only: deletes a specific user's row in `active_sessions`.
  /// RLS (the `is_admin()` policy on the table) gates the delete to
  /// admins only — students calling this will get 0 rows affected
  /// and the kicked row stays in place.
  @override
  Future<void> removeSessionById(String profileId) async {
    if (profileId.isEmpty) return;
    await _client.rpc(
      'end_active_session',
      params: {'p_profile_id': profileId, 'p_reason': 'force_logout'},
    );
  }

  /// Admin-only audit log: every row in `session_history` joined with
  /// the matching `profiles` row. RLS in migration 0006 already gates
  /// the read to admins (`session_history_admin_read`).
  ///
  /// We then enrich each entry with the number + names of borrowings
  /// that were created during the `(logged_in_at, ended_at)` window
  /// so the admin can see *what* the user did during the session.
  /// The activity lookup is a single batched query keyed on the set of
  /// `profile_id`s from the fetched sessions, so the cost is O(1)
  /// round-trips regardless of `limit`.
  @override
  Future<List<LoginHistoryEntry>> getLoginHistory({int limit = 100}) async {
    if (_client.auth.currentUser == null) return const [];

    final rows = await _client
        .from('session_history')
        .select(
          'id, profile_id, logged_in_at, last_activity_at, ended_at, end_reason, '
          'profiles:profile_id ( '
          '  student_id, full_name, email, program, year_level, section, role '
          ')',
        )
        .order('ended_at', ascending: false)
        .limit(limit);

    if (rows.isEmpty) return const [];

    final entries = rows
        .map<LoginHistoryEntry?>(_loginHistoryFromRow)
        .whereType<LoginHistoryEntry>()
        .toList(growable: false);
    if (entries.isEmpty) return const [];

    // Batched activity lookup: borrowings whose `requested_at` falls
    // inside any of the session windows we just fetched.
    final profileIds = entries.map((e) => e.profileId).toSet().toList();
    final earliest = entries
        .map((e) => e.loggedInAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final borrows = await _client
        .from('borrowings')
        .select('student_id, equipment_id, requested_at, equipment ( name )')
        .inFilter('student_id', profileIds)
        .gte('requested_at', earliest.toIso8601String());

    final byProfile = <String, List<Map<String, dynamic>>>{};
    for (final row in borrows) {
      final pid = row['student_id'] as String?;
      if (pid == null) continue;
      (byProfile[pid] ??= <Map<String, dynamic>>[]).add(row);
    }

    return entries.map((e) {
      final events = byProfile[e.profileId] ?? const [];
      final inside = events.where((b) {
        final t = DateTime.tryParse((b['requested_at'] as String?) ?? '');
        if (t == null) return false;
        return !t.isBefore(e.loggedInAt) && !t.isAfter(e.endedAt);
      }).toList();
      final names = <String>[];
      for (final b in inside) {
        final equip = b['equipment'];
        if (equip is Map && equip['name'] is String) {
          names.add(equip['name'] as String);
        }
      }
      return LoginHistoryEntry(
        id: e.id,
        profileId: e.profileId,
        studentId: e.studentId,
        fullName: e.fullName,
        email: e.email,
        program: e.program,
        yearLevel: e.yearLevel,
        section: e.section,
        role: e.role,
        loggedInAt: e.loggedInAt,
        lastActivityAt: e.lastActivityAt,
        endedAt: e.endedAt,
        endReason: e.endReason,
        borrowingsDuringSession: inside.length,
        activityNames: names.length > 5 ? names.sublist(0, 5) : names,
      );
    }).toList(growable: false);
  }

  static LoginHistoryEntry? _loginHistoryFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    if (profile == null) return null; // orphaned row, skip it
    final id = row['id'] as String?;
    final profileId = row['profile_id'] as String?;
    if (id == null || profileId == null) return null;

    return LoginHistoryEntry(
      id: id,
      profileId: profileId,
      studentId: (profile['student_id'] as String?) ?? profileId,
      fullName:
          (profile['full_name'] as String?) ??
          (profile['email'] as String?) ??
          'Unknown user',
      email: (profile['email'] as String?) ?? '',
      program: (profile['program'] as String?) ?? '',
      yearLevel: (profile['year_level'] as String?) ?? '',
      section: (profile['section'] as String?) ?? '',
      role: (profile['role'] as String?) ?? 'student',
      loggedInAt:
          DateTime.tryParse((row['logged_in_at'] as String?) ?? '') ??
          DateTime.now(),
      lastActivityAt:
          DateTime.tryParse((row['last_activity_at'] as String?) ?? '') ??
          DateTime.now(),
      endedAt:
          DateTime.tryParse((row['ended_at'] as String?) ?? '') ??
          DateTime.now(),
      endReason: (row['end_reason'] as String?) ?? 'closed',
      borrowingsDuringSession: 0,
      activityNames: const [],
    );
  }
}
