import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'models.dart';

class StudentMockData {
  static const String studentName = 'Juan Dela Cruz';
  static const String studentProgram = 'BS Electronics Engineering';
  static const String studentId = '2024-0xxxx-MN-0';
  static const String studentEmail =
      'juan.delacruz@iskolarngbayan.pup.edu.ph';
  static const String studentYearLevel = '3rd Year';
  static const String studentSection = 'MN-0';
  static final DateTime memberSince = DateTime(2024, 8, 15);

  static final List<Equipment> equipment = [
    const Equipment(
      id: 'E-1024',
      name: 'Fluke 87V Multimeter',
      category: 'Electrical',
      location: 'Room 301 - Electronics Lab',
      available: 3,
      total: 5,
      description:
          'Professional-grade digital multimeter with auto-ranging and high accuracy.',
    ),
    const Equipment(
      id: 'E-2033',
      name: 'Wrench Set 12pc',
      category: 'Mechanical',
      location: 'Room 205 - Tool Room',
      available: 2,
      total: 6,
      description:
          'General-purpose wrench set suitable for lab equipment maintenance.',
    ),
    const Equipment(
      id: 'E-3101',
      name: 'Arduino UNO R3',
      category: 'Testers',
      location: 'Room 312 - Embedded Lab',
      available: 0,
      total: 4,
      description:
          'Widely used microcontroller board for prototyping sensors and circuits.',
    ),
    const Equipment(
      id: 'E-4017',
      name: 'Oscilloscope Kit (DSO)',
      category: 'Electrical',
      location: 'Room 301 - Electronics Lab',
      available: 1,
      total: 3,
      description:
          'Compact oscilloscope kit with probes, enabling fast waveform verification.',
    ),
    const Equipment(
      id: 'E-5222',
      name: 'Power Supply 0-30V',
      category: 'Tools',
      location: 'Room 210 - Bench Supplies',
      available: 4,
      total: 4,
      description:
          'Bench power supply for regulating voltage and current during experiments.',
    ),
    const Equipment(
      id: 'E-6110',
      name: 'Digital Caliper (150mm)',
      category: 'Mechanical',
      location: 'Room 205 - Tool Room',
      available: 0,
      total: 2,
      description:
          'High precision measuring tool for mechanical fabrication tasks.',
    ),
    const Equipment(
      id: 'E-7007',
      name: 'LCR Meter',
      category: 'Testers',
      location: 'Room 301 - Electronics Lab',
      available: 2,
      total: 2,
      description:
          'Measure inductance, capacitance, and resistance for component characterization.',
    ),
    const Equipment(
      id: 'E-8008',
      name: 'Heat Gun (2 Modes)',
      category: 'Tools',
      location: 'Room 205 - Tool Room',
      available: 1,
      total: 2,
      description:
          'Adjustable heat gun for electronics rework and prototyping.',
    ),
    const Equipment(
      id: 'E-9020',
      name: 'Multimeter Probe Set',
      category: 'Electrical',
      location: 'Room 301 - Electronics Lab',
      available: 3,
      total: 3,
      description:
          'Probe set for safe and accurate measurement across lab devices.',
    ),
    const Equipment(
      id: 'E-10001',
      name: 'Screwdriver Kit',
      category: 'Mechanical',
      location: 'Room 205 - Tool Room',
      available: 2,
      total: 5,
      description:
          'Magnetic screwdriver kit for electronics and mechanical assembly.',
    ),
  ];

  static final List<Borrowing> activeBorrowings = [
    Borrowing(
      id: 'B-001',
      equipmentId: 'E-1024',
      equipmentName: 'Fluke 87V Multimeter',
      borrowDate: DateTime.now().subtract(const Duration(hours: 6)),
      returnDate: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
      status: BorrowingStatus.active,
      qrCode: 'QR-2024-001',
    ),
    Borrowing(
      id: 'B-002',
      equipmentId: 'E-2033',
      equipmentName: 'Wrench Set 12pc',
      borrowDate: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      returnDate: DateTime.now().add(const Duration(days: 1, hours: 3)),
      status: BorrowingStatus.active,
      qrCode: 'QR-2024-002',
    ),
    Borrowing(
      id: 'B-003',
      equipmentId: 'E-5222',
      equipmentName: 'Power Supply 0-30V',
      borrowDate: DateTime.now().subtract(const Duration(hours: 4)),
      returnDate: DateTime.now().add(const Duration(minutes: 40)),
      status: BorrowingStatus.active,
      qrCode: 'QR-2024-003',
    ),
  ];

  static final List<Borrowing> overdueBorrowings = [
    Borrowing(
      id: 'B-010',
      equipmentId: 'E-3101',
      equipmentName: 'Arduino UNO R3',
      borrowDate: DateTime.now().subtract(const Duration(days: 4)),
      returnDate: DateTime.now().subtract(const Duration(hours: 5)),
      status: BorrowingStatus.overdue,
      qrCode: 'QR-2024-010',
    ),
  ];

  static final List<Borrowing> pendingBorrowings = [
    Borrowing(
      id: 'B-2001',
      equipmentId: 'E-1024',
      equipmentName: 'Fluke 87V Multimeter',
      studentId: '2023-01234-MN-0',
      studentName: 'Maria Santos',
      purpose: 'Electronics lab experiment — RLC circuit characterization.',
      borrowDate: DateTime.now().subtract(const Duration(hours: 3)),
      returnDate: DateTime.now().add(const Duration(days: 3)),
      status: BorrowingStatus.pending,
      qrCode: 'QR-2024-2001',
    ),
    Borrowing(
      id: 'B-2002',
      equipmentId: 'E-3101',
      equipmentName: 'Arduino UNO R3',
      studentId: '2023-05678-MN-0',
      studentName: 'Pedro Garcia',
      purpose: 'Thesis prototype — sensor data acquisition board.',
      borrowDate: DateTime.now().subtract(const Duration(hours: 8)),
      returnDate: DateTime.now().add(const Duration(days: 2)),
      status: BorrowingStatus.pending,
      qrCode: 'QR-2024-2002',
    ),
    Borrowing(
      id: 'B-2003',
      equipmentId: 'E-4017',
      equipmentName: 'Oscilloscope Kit (DSO)',
      studentId: '2024-09012-MN-0',
      studentName: 'Ana Reyes',
      purpose: 'Signal integrity analysis for capstone project.',
      borrowDate: DateTime.now().subtract(const Duration(hours: 1)),
      returnDate: DateTime.now().add(const Duration(days: 4)),
      status: BorrowingStatus.pending,
      qrCode: 'QR-2024-2003',
    ),
  ];

  static final List<Borrowing> historyBorrowings = [
    Borrowing(
      id: 'B-100',
      equipmentId: 'E-4017',
      equipmentName: 'Oscilloscope Kit (DSO)',
      borrowDate: DateTime.now().subtract(const Duration(days: 8)),
      returnDate: DateTime.now().subtract(const Duration(days: 5)),
      status: BorrowingStatus.returned,
      qrCode: 'QR-2024-100',
    ),
    Borrowing(
      id: 'B-101',
      equipmentId: 'E-2033',
      equipmentName: 'Wrench Set 12pc',
      borrowDate: DateTime.now().subtract(const Duration(days: 14)),
      returnDate: DateTime.now().subtract(const Duration(days: 13)),
      status: BorrowingStatus.approved,
      qrCode: 'QR-2024-101',
    ),
    Borrowing(
      id: 'B-102',
      equipmentId: 'E-9020',
      equipmentName: 'Multimeter Probe Set',
      borrowDate: DateTime.now().subtract(const Duration(days: 20)),
      returnDate: DateTime.now().subtract(const Duration(days: 19)),
      status: BorrowingStatus.rejected,
      qrCode: 'QR-2024-102',
    ),
  ];

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'N-001',
      title: 'Request Approved ✅',
      message: 'Your request for Fluke 87V Multimeter was approved!',
      type: NotificationType.approved,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    AppNotification(
      id: 'N-002',
      title: 'Reminder ⏰',
      message: 'Power Supply is due in 2 hours!',
      type: NotificationType.reminder,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: false,
    ),
    AppNotification(
      id: 'N-003',
      title: 'Overdue ⚠️',
      message: 'Arduino UNO R3 is overdue. Please pay the fine.',
      type: NotificationType.overdue,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      isRead: false,
    ),
    AppNotification(
      id: 'N-004',
      title: 'New equipment added 🆕',
      message: 'Oscilloscope Kit is now available for borrowing.',
      type: NotificationType.newItem,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      isRead: true,
    ),
    AppNotification(
      id: 'N-005',
      title: 'Returned ↩️',
      message: 'You successfully returned Wrench Set 12pc.',
      type: NotificationType.returned,
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      isRead: true,
    ),
  ];

  static int unreadCount(List<AppNotification> list) =>
      list.where((n) => !n.isRead).length;

  /// Mock weekly activity numbers (7 days, oldest → newest).
  /// Drives the dashboard bar chart.
  static final List<int> weeklyActivity = [12, 18, 9, 22, 27, 14, 19];

  /// Mock "currently logged in" sessions. Seed values for the admin
  /// occupancy monitor. Mix of states (active / idle / returning) so the
  /// monitor looks real out of the box.
  static final List<ActiveSession> activeSessions = [
    ActiveSession(
      id: 'S-001',
      studentId: '2024-08721-MN-0',
      studentName: 'Juan Dela Cruz',
      program: 'BS Electronics Engineering',
      equipmentName: 'Fluke 87V Multimeter',
      equipmentId: 'E-1024',
      location: 'Room 301 - Electronics Lab',
      loginAt: DateTime.now().subtract(const Duration(minutes: 38)),
      lastActivityAt: DateTime.now().subtract(const Duration(seconds: 12)),
      activity: SessionActivity.active,
    ),
    ActiveSession(
      id: 'S-002',
      studentId: '2023-01234-MN-0',
      studentName: 'Maria Santos',
      program: 'BS Electronics Engineering',
      equipmentName: 'Oscilloscope Kit (DSO)',
      equipmentId: 'E-4017',
      location: 'Room 301 - Electronics Lab',
      loginAt: DateTime.now().subtract(const Duration(minutes: 22)),
      lastActivityAt: DateTime.now().subtract(const Duration(minutes: 7)),
      activity: SessionActivity.idle,
    ),
    ActiveSession(
      id: 'S-003',
      studentId: '2023-05678-MN-0',
      studentName: 'Pedro Garcia',
      program: 'BS Computer Engineering',
      equipmentName: 'Arduino UNO R3',
      equipmentId: 'E-3101',
      location: 'Room 312 - Embedded Lab',
      loginAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
      lastActivityAt: DateTime.now().subtract(const Duration(seconds: 45)),
      activity: SessionActivity.active,
    ),
    ActiveSession(
      id: 'S-004',
      studentId: '2024-09012-MN-0',
      studentName: 'Ana Reyes',
      program: 'BS Electronics Engineering',
      equipmentName: '',
      equipmentId: '',
      location: 'Browsing inventory',
      loginAt: DateTime.now().subtract(const Duration(minutes: 5)),
      lastActivityAt: DateTime.now().subtract(const Duration(seconds: 4)),
      activity: SessionActivity.active,
    ),
    ActiveSession(
      id: 'S-005',
      studentId: '2022-07777-MN-0',
      studentName: 'Carlos Mendoza',
      program: 'BS Mechanical Engineering',
      equipmentName: 'Wrench Set 12pc',
      equipmentId: 'E-2033',
      location: 'Room 205 - Tool Room',
      loginAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 12)),
      lastActivityAt: DateTime.now().subtract(const Duration(minutes: 2, seconds: 10)),
      activity: SessionActivity.returning,
    ),
    ActiveSession(
      id: 'S-006',
      studentId: '2024-00123-MN-0',
      studentName: 'Liza Aquino',
      program: 'BS Computer Engineering',
      equipmentName: 'LCR Meter',
      equipmentId: 'E-7007',
      location: 'Room 301 - Electronics Lab',
      loginAt: DateTime.now().subtract(const Duration(minutes: 14)),
      lastActivityAt: DateTime.now().subtract(const Duration(seconds: 22)),
      activity: SessionActivity.active,
    ),
  ];

  /// Mock activity log. Mixed scopes so both the admin dashboard's
  /// "Recent Activity" feed and the student home "Recently Borrowed"
  /// section have content to show.
  static final List<ActivityEntry> activity = [
    ActivityEntry(
      icon: Icons.check_circle_rounded,
      tone: PupColors.mintGreen,
      title: 'Approved: Fluke 87V Multimeter',
      subtitle: 'Maria Santos • 2023-01234-MN-0',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      scope: ActivityScope.admin,
    ),
    ActivityEntry(
      icon: Icons.assignment_return_rounded,
      tone: PupColors.mintGreen,
      title: 'Returned: Wrench Set 12pc',
      subtitle: 'On time • Thank you!',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      scope: ActivityScope.student,
    ),
    ActivityEntry(
      icon: Icons.qr_code_scanner_rounded,
      tone: PupColors.techCyan,
      title: 'Scanned: Power Supply 0-30V',
      subtitle: 'Out to Juan Dela Cruz',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      scope: ActivityScope.admin,
    ),
    ActivityEntry(
      icon: Icons.pending_actions_rounded,
      tone: PupColors.cyberAmber,
      title: 'New request: Oscilloscope Kit',
      subtitle: 'Ana Reyes • Capstone project',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
      scope: ActivityScope.admin,
    ),
    ActivityEntry(
      icon: Icons.handyman_rounded,
      tone: PupColors.cyberAmber,
      title: 'Borrowed: Screwdriver Kit',
      subtitle: 'Mechanical workbench repair',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      scope: ActivityScope.student,
    ),
    ActivityEntry(
      icon: Icons.cancel_rounded,
      tone: PupColors.signalRed,
      title: 'Rejected: Digital Caliper',
      subtitle: 'Insufficient units available',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      scope: ActivityScope.admin,
    ),
    ActivityEntry(
      icon: Icons.assignment_return_rounded,
      tone: PupColors.mintGreen,
      title: 'Returned: Multimeter Probe Set',
      subtitle: 'On time • Thank you!',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      scope: ActivityScope.student,
    ),
  ];
}
