import 'package:flutter/foundation.dart';

import '../../student/mock_data.dart';
import '../../student/models.dart';

/// The currently-authenticated user's profile. In production this is
/// hydrated from Firebase Auth + the user's Firestore document.
@immutable
class UserProfile {
  const UserProfile({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentProgram,
    required this.studentYearLevel,
    required this.studentSection,
    required this.memberSince,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentProgram;
  final String studentYearLevel;
  final String studentSection;
  final DateTime memberSince;
}

/// Contract for fetching the current user + the live-occupancy feed.
///
/// Today: returns the seed `StudentMockData` profile and a static
/// `activeSessions` list for the offline demo.
/// Tomorrow: `FirebaseUserRepository` returns the Firestore user doc.
abstract class UserRepository {
  /// The auth UUID of the currently signed-in user, or null when
  /// signed out. The `active_sessions` table is keyed on this
  /// value (not on `profiles.student_id`), so the controller needs
  /// it to correlate the user's own row in the live-occupancy feed
  /// with the signed-in account.
  String? get currentAuthId;

  Future<UserProfile> getCurrentUser();

  /// Updates the editable, non-privileged fields of the signed-in profile.
  /// Roles, email, and student ID are intentionally not client-editable.
  Future<void> updateCurrentProfile({
    required String fullName,
    required String program,
    required String yearLevel,
    required String section,
  });

  /// Every active session the current user is allowed to see. Admins
  /// see everyone; students see only themselves (enforced by the
  /// `active_sessions` RLS policy `profile_id = auth.uid() or
  /// is_admin()`).
  Future<List<ActiveSession>> getActiveSessions();

  /// Emits the active-session feed whenever another device signs in, sends a
  /// heartbeat, signs out, or is force-logged-out. The initial emission is
  /// also a complete snapshot, so the Live screen does not have to wait for
  /// a manual refresh before it can show a newly logged-in student.
  Stream<List<ActiveSession>> watchActiveSessions();

  /// Emits whether the SIGNED-IN user currently has their own row in
  /// `active_sessions`. Realtime-backed in the Supabase bundle: when an
  /// admin force-logs this account out, the row is deleted and the stream
  /// emits `false`, which the session lifecycle guard turns into an
  /// immediate local sign-out. Emits nothing when signed out.
  Stream<bool> watchOwnSessionPresence();

  /// Best-effort cleanup of the current user's session row. Called on
  /// sign-out (and on app pause / detach) so the Live tab reflects
  /// reality instead of accumulating every account that's ever signed
  /// in.
  Future<void> removeOwnSession();

  /// Re-registers (or refreshes) the current user's `active_sessions`
  /// row. Called on app launch and on `onResume` so a user who
  /// backgrounded and reopened the app is visible on the admin's
  /// Live tab again.
  Future<void> markOwnSessionActive();

  /// Admin: forcibly end another user's session. Deletes the row in
  /// `active_sessions` for `profileId`. Students must not be able to
  /// call this — the Supabase bundle relies on the RLS policy
  /// `is_admin()` to gate it server-side.
  Future<void> removeSessionById(String profileId);

  /// Admin-only audit log: every row in `session_history` joined with
  /// the matching `profiles` row, plus a count of borrowings that
  /// happened during each session window. Newest first.
  ///
  /// RLS in the Supabase bundle restricts this to admins via the
  /// `session_history_admin_read` policy (see migration 0006). The
  /// mock bundle just hands back the seed list from
  /// `StudentMockData.loginHistory`.
  Future<List<LoginHistoryEntry>> getLoginHistory({int limit = 100});
}

/// Mock implementation — reads from `StudentMockData`.
class MockUserRepository implements UserRepository {
  const MockUserRepository();

  @override
  String? get currentAuthId => null;

  @override
  Future<UserProfile> getCurrentUser() async {
    return UserProfile(
      studentId: StudentMockData.studentId,
      studentName: StudentMockData.studentName,
      studentEmail: StudentMockData.studentEmail,
      studentProgram: StudentMockData.studentProgram,
      studentYearLevel: StudentMockData.studentYearLevel,
      studentSection: StudentMockData.studentSection,
      memberSince: StudentMockData.memberSince,
    );
  }

  @override
  Future<void> updateCurrentProfile({
    required String fullName,
    required String program,
    required String yearLevel,
    required String section,
  }) async {
    // The offline demo does not persist profile edits between launches.
  }

  @override
  Future<List<ActiveSession>> getActiveSessions() async {
    // Offline demo: just hand back the seed list. The admin occupancy
    // screen treats this exactly like a real query — the difference
    // is only that the data is static and lives in the bundle.
    return List.unmodifiable(StudentMockData.activeSessions);
  }

  @override
  Stream<List<ActiveSession>> watchActiveSessions() {
    return Stream.value(List.unmodifiable(StudentMockData.activeSessions));
  }

  @override
  Stream<bool> watchOwnSessionPresence() {
    // Offline demo: presence never disappears on its own, so there is
    // nothing to watch.
    return const Stream<bool>.empty();
  }

  @override
  Future<void> removeOwnSession() async {
    // No-op for the mock — there's no DB row to delete.
  }

  @override
  Future<void> markOwnSessionActive() async {
    // No-op for the mock — the seed list is static, so the
    // `kickSession` flow on the admin screen is the only mutation.
  }

  @override
  Future<void> removeSessionById(String profileId) async {
    // No-op for the mock — the kick UI already removes the row from
    // the local cache; there's no DB to keep in sync.
  }

  @override
  Future<List<LoginHistoryEntry>> getLoginHistory({int limit = 100}) async {
    // The mock simply hands back the seed list (already newest first).
    final list = StudentMockData.loginHistory;
    if (list.length <= limit) return List.unmodifiable(list);
    return List.unmodifiable(list.take(limit));
  }
}
