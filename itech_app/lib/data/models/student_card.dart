import 'package:flutter/foundation.dart';

/// Identity of a student resolved from a tapped NFC card.
///
/// In production this comes from the backend roster. For the thesis
/// demo, a [StudentCardRegistry] holds a small in-memory map so the
/// flow can be exercised without a server.
@immutable
class StudentCard {
  const StudentCard({
    required this.uid,
    required this.studentId,
    required this.fullName,
    required this.program,
    required this.yearSection,
  });

  /// Tapped UID in colon-hex form (matches [NfcTap.uidHex]).
  final String uid;

  /// School-issued student number, e.g. `2023-00456-TG-0`.
  final String studentId;

  final String fullName;
  final String program;
  final String yearSection;
}

/// Mock UID → student lookup. Seed with a handful of entries for the
/// demo so the panel can tap any of three test cards and see the full
/// borrow/return flow light up.
class StudentCardRegistry {
  StudentCardRegistry._();
  static final StudentCardRegistry instance = StudentCardRegistry._();

  final Map<String, StudentCard> _byUid = {
    // Sample 1 — student with an active borrowing (Fluke 87V).
    '04:A3:B2:7F:1C:90:80': const StudentCard(
      uid: '04:A3:B2:7F:1C:90:80',
      studentId: '2023-00456-TG-0',
      fullName: 'Juan dela Cruz',
      program: 'BS Computer Engineering',
      yearSection: '3-1',
    ),
    // Sample 2 — student with an overdue Arduino kit.
    '04:7C:C2:9D:11:22:33': const StudentCard(
      uid: '04:7C:C2:9D:11:22:33',
      studentId: '2024-01128-TG-0',
      fullName: 'Maria Santos',
      program: 'BS Electronics Engineering',
      yearSection: '2-2',
    ),
    // Sample 3 — student with no active borrowings.
    '04:DE:AD:BE:EF:00:01': const StudentCard(
      uid: '04:DE:AD:BE:EF:00:01',
      studentId: '2022-00789-TG-0',
      fullName: 'Pedro Reyes',
      program: 'BS Electrical Engineering',
      yearSection: '4-1',
    ),
  };

  /// Look up a student by the colon-hex UID from [NfcService].
  /// Returns null if the card is not in the registry.
  StudentCard? lookup(String uidHex) {
    final upper = uidHex.toUpperCase();
    return _byUid[upper] ?? _byUid[upper.replaceAll(':', '')];
  }
}
