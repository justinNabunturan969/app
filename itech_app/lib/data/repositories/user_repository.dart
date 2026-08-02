import 'package:flutter/foundation.dart';

import '../../student/mock_data.dart';

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

/// Contract for fetching the current user.
///
/// Today: returns the seed `StudentMockData` profile.
/// Tomorrow: `FirebaseUserRepository` returns the Firestore user doc.
abstract class UserRepository {
  Future<UserProfile> getCurrentUser();
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
}
