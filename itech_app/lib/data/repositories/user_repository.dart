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
  /// sign-out so the Live tab reflects reality instead of accumulating
  /// every account that's ever signed in.
  Future<void> removeOwnSession();
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
}
