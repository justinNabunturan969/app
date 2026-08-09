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
}

/// Mock implementation — reads from `StudentMockData`.
class MockUserRepository implements UserRepository {
  const MockUserRepository();

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
}
