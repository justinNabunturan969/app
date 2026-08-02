import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'mock_data.dart';
import 'models.dart';

class StudentDashboardController extends ChangeNotifier {
  StudentDashboardController() {
    // Eagerly initialise the notifications list (instead of `late`) so any
    // failure happens at construction time with a clear stack, rather than
    // at first access deep in the widget tree. Was previously `late ... =`
    // which is fine in theory but caused subtle rebuild-time failures when
    // the same instance was re-read across hot reloads.
    _notifications = List.of(StudentMockData.notifications);
    _unread = StudentMockData.unreadCount(_notifications);
    _searchDebounceTimer?.cancel();
    _startTicker();
    _startOccupancyRotator();
  }

  // Mock "profile"
  final String studentName = StudentMockData.studentName;
  final String studentProgram = StudentMockData.studentProgram;
  final String studentId = StudentMockData.studentId;
  final String studentEmail = StudentMockData.studentEmail;
  final String studentYearLevel = StudentMockData.studentYearLevel;
  final String studentSection = StudentMockData.studentSection;
  final DateTime memberSince = StudentMockData.memberSince;

  /// First name only — used by the home greeting so we don't hardcode
  /// "Juan" anymore.
  String get studentFirstName {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Student';
    return parts.first;
  }

  /// Two-letter initials for the avatar button.
  String get studentInitials {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? 'S'
          : parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Lightweight audit log used by the admin "Recent Activity" feed and
  /// the student "Recently Borrowed" section. Mutations append a row and
  /// notify listeners.
  final List<ActivityEntry> _activity = List.of(StudentMockData.activity);
  List<ActivityEntry> get activity => List.unmodifiable(_activity);

  /// 7-day daily activity numbers, used by the dashboard chart.
  final List<int> weeklyActivity = List.of(StudentMockData.weeklyActivity);

  /// 3 most-recent items the student has borrowed or returned, for the
  /// "Recently Borrowed" section on the home screen.
  List<ActivityEntry> get recentStudentActivity =>
      _activity.where((a) => a.scope == ActivityScope.student).take(3).toList();

  // Occupancy monitor ────────────────────────────────────────────────────
  // The admin "Live" tab shows who is logged in right now. For the
  // prototype we mock the sessions in [StudentMockData.activeSessions] and
  // mutate them on a slow rotation timer so the count feels live.

  final List<ActiveSession> _activeSessions =
      List.of(StudentMockData.activeSessions);
  List<ActiveSession> get activeSessions => List.unmodifiable(_activeSessions);

  int get occupancyCount => _activeSessions.length;

  int get activeOccupancyCount => _activeSessions
      .where((s) => s.activity == SessionActivity.active)
      .length;
  int get idleOccupancyCount => _activeSessions
      .where((s) => s.activity == SessionActivity.idle)
      .length;
  int get returningOccupancyCount => _activeSessions
      .where((s) => s.activity == SessionActivity.returning)
      .length;

  /// Slow ticker that mutates sessions so the monitor feels alive. Runs
  /// every ~18s, well below human attention threshold.
  Timer? _occupancyRotator;
  int _rotationTick = 0;

  void _startOccupancyRotator() {
    _occupancyRotator?.cancel();
    _occupancyRotator = Timer.periodic(
      const Duration(seconds: 18),
      (_) => _rotateSessions(),
    );
  }

  void _rotateSessions() {
    if (_activeSessions.isEmpty) return;
    _rotationTick++;

    // Every other tick: mark the longest-active "active" session as
    // idle (simulates the user stepping away).
    if (_rotationTick % 2 == 0) {
      final candidates = _activeSessions
          .where((s) => s.activity == SessionActivity.active)
          .toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) =>
            a.lastActivityAt.isBefore(b.lastActivityAt) ? 1 : -1);
        final oldest = candidates.first;
        final idx = _activeSessions.indexWhere((s) => s.id == oldest.id);
        if (idx != -1) {
          _activeSessions[idx] = oldest.copyWith(
            activity: SessionActivity.idle,
            lastActivityAt: DateTime.now()
                .subtract(const Duration(minutes: 6, seconds: 30)),
          );
          notifyListeners();
        }
      }
      return;
    }

    // Otherwise: bring in a new mock session (simulates someone logging
    // in) and drop the most-idle one to keep the list bounded.
    if (_activeSessions.length >= 10) {
      final idleCandidates = _activeSessions
          .where((s) => s.activity == SessionActivity.idle)
          .toList();
      if (idleCandidates.isNotEmpty) {
        idleCandidates.sort((a, b) =>
            a.lastActivityAt.isBefore(b.lastActivityAt) ? 1 : -1);
        _activeSessions
            .removeWhere((s) => s.id == idleCandidates.first.id);
      }
    }

    final newId = 'S-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final names = [
      ('Ramon Cruz', '2024-04421-MN-0', 'BS Electronics Engineering'),
      ('Ella Bautista', '2023-02110-MN-0', 'BS Computer Engineering'),
      ('Diego Reyes', '2024-08812-MN-0', 'BS Mechanical Engineering'),
      ('Sofia Lim', '2023-07733-MN-0', 'BS Electronics Engineering'),
      ('Marco Villanueva', '2024-01560-MN-0', 'BS Computer Engineering'),
    ];
    final pick = names[DateTime.now().second % names.length];
    final equipmentChoices = [
      ('Multimeter Probe Set', 'E-9020', 'Room 301 - Electronics Lab'),
      ('Screwdriver Kit', 'E-10001', 'Room 205 - Tool Room'),
      ('Heat Gun (2 Modes)', 'E-8008', 'Room 205 - Tool Room'),
      ('Power Supply 0-30V', 'E-5222', 'Room 210 - Bench Supplies'),
    ];
    final eq = equipmentChoices[DateTime.now().minute % equipmentChoices.length];

    _activeSessions.insert(
      0,
      ActiveSession(
        id: newId,
        studentId: pick.$2,
        studentName: pick.$1,
        program: pick.$3,
        equipmentName: eq.$1,
        equipmentId: eq.$2,
        location: eq.$3,
        loginAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        activity: SessionActivity.active,
      ),
    );
    notifyListeners();
  }

  /// Admin: forcibly log a user out. Removes the session and logs it.
  void kickSession(String id) {
    final idx = _activeSessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final removed = _activeSessions.removeAt(idx);
    _log(
      scope: ActivityScope.admin,
      icon: Icons.logout_rounded,
      tone: PupColors.signalRed,
      title: 'Forced logout: ${removed.studentName}',
      subtitle: '${removed.studentId} • Session terminated by admin',
    );
    notifyListeners();
  }

  // Equipment
  List<Equipment> _equipment = List.of(StudentMockData.equipment);
  List<Equipment> get equipment => _equipment;

  // Borrowings
  final List<Borrowing> activeBorrowings = List.of(
    StudentMockData.activeBorrowings,
  );
  final List<Borrowing> overdueBorrowings = List.of(
    StudentMockData.overdueBorrowings,
  );
  final List<Borrowing> historyBorrowings = List.of(
    StudentMockData.historyBorrowings,
  );
  final List<Borrowing> pendingBorrowings = List.of(
    StudentMockData.pendingBorrowings,
  );

  // Requests / pending (mock derived)
  int get pendingRequestsCount => pendingBorrowings.length;
  int get activeBorrowingsCount => activeBorrowings.length;
  int get overdueCount => overdueBorrowings.length;
  int get returnedCount => historyBorrowings
      .where((b) => b.status == BorrowingStatus.returned)
      .length;
  int get totalLoans => activeBorrowingsCount +
      overdueCount +
      historyBorrowings.length +
      pendingBorrowings.length;

  // Borrowings actions
  /// Marks the borrowing as returned and moves it from `activeBorrowings` or
  /// `overdueBorrowings` to the top of `historyBorrowings` with the current
  /// time as the return date. No-op if the id is not found.
  void returnBorrowing(String id) {
    Borrowing? found;
    final i = activeBorrowings.indexWhere((b) => b.id == id);
    if (i != -1) {
      found = activeBorrowings.removeAt(i);
    } else {
      final j = overdueBorrowings.indexWhere((b) => b.id == id);
      if (j != -1) {
        found = overdueBorrowings.removeAt(j);
      }
    }
    if (found != null) {
      historyBorrowings.insert(
        0,
        found.copyWith(
          status: BorrowingStatus.returned,
          returnDate: DateTime.now(),
        ),
      );
      _log(
        scope: ActivityScope.student,
        icon: Icons.assignment_return_rounded,
        tone: PupColors.mintGreen,
        title: 'Returned: ${found.equipmentName}',
        subtitle: 'On time • Thank you!',
      );
      notifyListeners();
    }
  }

  /// Admin: approves a pending request. Moves it from `pendingBorrowings`
  /// to `activeBorrowings` with status=active and borrowDate=now. The
  /// requested return date is preserved.
  void approveBorrowing(String id) {
    final i = pendingBorrowings.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final found = pendingBorrowings.removeAt(i);
    activeBorrowings.insert(
      0,
      found.copyWith(
        status: BorrowingStatus.active,
        borrowDate: DateTime.now(),
      ),
    );
    _log(
      scope: ActivityScope.admin,
      icon: Icons.check_circle_rounded,
      tone: PupColors.mintGreen,
      title: 'Approved: ${found.equipmentName}',
      subtitle: '${found.studentName} • ${found.studentId}',
    );
    notifyListeners();
  }

  /// Admin: rejects a pending request. Moves it from `pendingBorrowings`
  /// to `historyBorrowings` with status=rejected.
  void rejectBorrowing(String id) {
    final i = pendingBorrowings.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final found = pendingBorrowings.removeAt(i);
    historyBorrowings.insert(
      0,
      found.copyWith(
        status: BorrowingStatus.rejected,
        returnDate: DateTime.now(),
      ),
    );
    _log(
      scope: ActivityScope.admin,
      icon: Icons.cancel_rounded,
      tone: PupColors.signalRed,
      title: 'Rejected: ${found.equipmentName}',
      subtitle: '${found.studentName} • ${found.studentId}',
    );
    notifyListeners();
  }

  // Notifications
  late final List<AppNotification> _notifications;
  List<AppNotification> get notifications => _notifications;

  int _unread = 0;
  int get unreadCount => _unread;

  // Search
  Timer? _searchDebounceTimer;
  final List<String> _recentSearches = ['Multimeter', 'Wrench Set', 'Arduino'];
  List<String> get recentSearches => _recentSearches;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _query = '';
  String get query => _query;

  List<Equipment> _filtered = [];
  List<Equipment> get filtered => _filtered;

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  Future<void> debounceSearch(String q) async {
    _query = q;
    notifyListeners();

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _runSearch(q);
    });
  }

  Future<void> submitSearch(String q) async {
    _searchDebounceTimer?.cancel();
    _query = q;
    notifyListeners();
    await _runSearch(q);
  }

  Future<void> _runSearch(String q) async {
    _isSearching = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      _filtered = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    final queryLower = trimmed.toLowerCase();
    _filtered = _equipment.where((e) {
      final inText =
          e.name.toLowerCase().contains(queryLower) ||
          e.id.toLowerCase().contains(queryLower);
      final inCategory = _selectedCategory == 'All'
          ? true
          : e.category == _selectedCategory;
      return inText && inCategory;
    }).toList();

    _isSearching = false;
    notifyListeners();

    _rememberSearch(trimmed);
  }

  void _rememberSearch(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    _recentSearches.removeWhere(
      (s) => s.toLowerCase() == trimmed.toLowerCase(),
    );
    _recentSearches.insert(0, trimmed);
    while (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }
  }

  void clearSearch() {
    _query = '';
    _filtered = [];
    _isSearching = false;
    notifyListeners();
  }

  void selectCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
    if (_query.trim().isNotEmpty) {
      // re-run
      debounceSearch(_query);
    }
  }

  // Likes
  void toggleLike(Equipment equipment) {
    // Haptic light (optional in this repo)
    // You can wire flutter/services Haptics plugin if/when needed.
    // ignore: deprecated_member_use
    // ignore: unused_local_variable
    // (No-op for now)

    _equipment = _equipment
        .map((e) => e.id == equipment.id ? e.copyWith(isLiked: !e.isLiked) : e)
        .toList();
    notifyListeners();
  }

  // Notifications actions
  void markAllRead() {
    for (final n in _notifications) {
      if (!n.isRead) {
        final idx = _notifications.indexOf(n);
        _notifications[idx] = n.copyWith(isRead: true);
      }
    }
    _recalcUnread();
  }

  void clearAll() {
    _notifications = [];
    _recalcUnread();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    _recalcUnread();
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _recalcUnread();
    notifyListeners();
  }

  /// Re-inserts a previously deleted notification (used by the swipe-to-delete
  /// "Undo" action). Inserts at the top of the list.
  void restoreNotification(AppNotification n) {
    _notifications.insert(0, n);
    _recalcUnread();
  }

  void _recalcUnread() {
    _unread = StudentMockData.unreadCount(_notifications);
    notifyListeners();
  }

  void _log({
    required ActivityScope scope,
    required IconData icon,
    required Color tone,
    required String title,
    required String subtitle,
  }) {
    _activity.insert(
      0,
      ActivityEntry(
        icon: icon,
        tone: tone,
        title: title,
        subtitle: subtitle,
        timestamp: DateTime.now(),
        scope: scope,
      ),
    );
    // Cap the log so it doesn't grow forever.
    while (_activity.length > 30) {
      _activity.removeLast();
    }
  }

  // Countdown tick to refresh timers every second.
  Timer? _ticker;
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchDebounceTimer?.cancel();
    _occupancyRotator?.cancel();
    super.dispose();
  }
}

/// Scope of an activity entry — drives which screens surface the row.
enum ActivityScope { admin, student }

/// One row in the in-app activity log.
class ActivityEntry {
  const ActivityEntry({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.scope,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ActivityScope scope;
}
