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
    final rows = await _client
        .from('active_sessions')
        .select(
          'profile_id, logged_in_at, last_activity_at, activity, '
          'current_equipment_id, '
          'profiles:profile_id ( student_id, full_name, email, program ), '
          'equipment:current_equipment_id ( id, name, location )',
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
  /// Live tab stops showing them after they sign out. Errors are
  /// swallowed — a stale row will eventually be cleaned up by the
  /// admin via Force Logout, or by a future "last activity > 24h"
  /// sweep.
  @override
  Future<void> removeOwnSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('active_sessions').delete().eq('profile_id', user.id);
    } catch (_) {
      // Best effort.
    }
  }
}
