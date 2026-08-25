import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/repository_bundle.dart';
import '../data/repositories/user_repository.dart' show UserProfile;
import '../theme/design_tokens.dart';
import 'models.dart'
    show
        ActiveSession,
        ActivityEntry,
        ActivityScope,
        AppNotification,
        Borrowing,
        BorrowingStatus,
        Equipment,
        LoginHistoryEntry,
        SessionActivity;

// Note: StudentMockData is still imported for the activity-feed seed
// values and a few static labels (the borrowings repository returns its own
// objects, but the activity log is generated locally from each CRUD op so
// it stays in sync with the UI without a DB round-trip).
import 'mock_data.dart' show StudentMockData;

/// Result of an admin force-logout issued from the Login History tab.
enum ForceLogoutOutcome {
  /// The user had a live session and it was terminated.
  terminated,

  /// The user is not currently signed in on any device.
  notOnline,

  /// The call failed (RLS rejection or network error).
  failed,
}

class StudentDashboardController extends ChangeNotifier {
  StudentDashboardController({required this.bundle}) {
    // Per-second ticker drives the "1h 23m left" countdown strings in the
    // borrowings list. Nothing in here touches the DB, so it's safe to
    // start before `load()` returns.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    // Start the borrowings Realtime feed immediately so cross-device
    // updates land as soon as the controller exists — the first emit
    // also gives us the initial state, so we don't have to wait for
    // `load()` to finish before the UI has data. The notifications
    // subscription is still started inside `load()` to keep the
    // existing flow intact.
    _startBorrowingsSubscription();
    _startActiveSessionsSubscription();
    // Safety net for the borrowings Realtime feed. The Supabase
    // `.stream()` API is supposed to deliver an event for every
    // INSERT / UPDATE / DELETE the current user is allowed to see, but
    // in practice (esp. on web behind flaky WebSockets) the channel
    // can silently stop emitting new rows. Without this poll, the
    // admin's Pending Requests list would only refresh when the app
    // is restarted, which is exactly the bug the realtime feed was
    // supposed to fix. A short periodic refetch keeps the queue
    // current even if a realtime event is missed.
    _borrowingsRefreshTimer?.cancel();
    _borrowingsRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshBorrowingsQuietly(),
    );
  }

  /// All CRUD goes through this bundle. The shell is responsible for
  /// constructing the bundle (mock or Supabase) and passing it here.
  final RepositoryBundle bundle;

  // ── Load state ─────────────────────────────────────────────────────────
  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ── Profile (from Supabase profiles table via UserRepository) ──────────
  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  String get studentName => _userProfile?.studentName ?? 'Student';
  String get studentProgram => _userProfile?.studentProgram ?? '';
  String get studentId => _userProfile?.studentId ?? '';
  String get studentEmail => _userProfile?.studentEmail ?? '';
  String get studentYearLevel => _userProfile?.studentYearLevel ?? '';
  String get studentSection => _userProfile?.studentSection ?? '';
  DateTime get memberSince =>
      _userProfile?.memberSince ?? DateTime(2024, 8, 15);

  /// First name only — used by the home greeting so we don't hardcode
  /// "Juan" anymore. Falls back to the static seed if the profile
  /// hasn't loaded yet (e.g. before the first `load()` finishes).
  String get studentFirstName {
    final source = _userProfile?.studentName ?? StudentMockData.studentName;
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Student';
    return parts.first;
  }

  /// Two-letter initials for the avatar button.
  String get studentInitials {
    final source = _userProfile?.studentName ?? StudentMockData.studentName;
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? 'S'
          : parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  // ── Equipment (from Supabase equipment table) ─────────────────────────
  List<Equipment> _equipment = const [];
  List<Equipment> get equipment => _equipment;

  // ── Borrowings (4 buckets) ────────────────────────────────────────────
  List<Borrowing> _activeBorrowings = const [];
  List<Borrowing> _overdueBorrowings = const [];
  List<Borrowing> _historyBorrowings = const [];
  List<Borrowing> _pendingBorrowings = const [];

  List<Borrowing> get activeBorrowings => List.unmodifiable(_activeBorrowings);
  List<Borrowing> get overdueBorrowings =>
      List.unmodifiable(_overdueBorrowings);
  List<Borrowing> get historyBorrowings =>
      List.unmodifiable(_historyBorrowings);
  List<Borrowing> get pendingBorrowings =>
      List.unmodifiable(_pendingBorrowings);

  int get pendingRequestsCount => _pendingBorrowings.length;
  int get activeBorrowingsCount => _activeBorrowings.length;
  int get overdueCount => _overdueBorrowings.length;
  int get returnedCount => _historyBorrowings
      .where((b) => b.status == BorrowingStatus.returned)
      .length;
  int get totalLoans =>
      activeBorrowingsCount +
      overdueCount +
      _historyBorrowings.length +
      _pendingBorrowings.length;

  /// Equipment IDs the current student already has an open request for
  /// (pending / active / overdue). Used by the home grid and search
  /// screen to hide "Tap to borrow" cards that would just bounce off
  /// the unique-index constraint in the DB.
  Set<String> get openRequestEquipmentIds {
    final ids = <String>{};
    for (final b in _pendingBorrowings) {
      if (b.equipmentId.isNotEmpty) ids.add(b.equipmentId);
    }
    for (final b in _activeBorrowings) {
      if (b.equipmentId.isNotEmpty) ids.add(b.equipmentId);
    }
    for (final b in _overdueBorrowings) {
      if (b.equipmentId.isNotEmpty) ids.add(b.equipmentId);
    }
    return ids;
  }

  // ── Notifications (from Supabase notifications table) ────────────────
  List<AppNotification> _notifications = const [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  StreamSubscription<List<AppNotification>>? _notificationsSubscription;

  // ── Borrowings (live feed from Supabase Realtime) ───────────────────
  // A single subscription to the `borrowings` table. Every INSERT / UPDATE
  // / DELETE the current user is allowed to see (per RLS) re-emits the
  // full list, which we re-partition into the four status buckets. This
  // is what makes the admin's "Pending Requests" list update on the
  // student's phone the moment a request lands — no app restart needed,
  // works across devices.
  StreamSubscription<List<Borrowing>>? _borrowingsSubscription;

  // Belt-and-suspenders for the borrowings feed: even if the Realtime
  // channel silently drops events (network blip, WebSocket sleep, the
  // browser throttling background tabs), this 15-second poll guarantees
  // the admin's queue is never more than 15s stale.
  Timer? _borrowingsRefreshTimer;

  int _unread = 0;
  int get unreadCount => _unread;

  // ── Activity log (local, derived from each CRUD op) ──────────────────
  final List<ActivityEntry> _activity = List.of(StudentMockData.activity);
  List<ActivityEntry> get activity => List.unmodifiable(_activity);

  /// Borrowed-unit totals for the current Monday–Sunday week. The values are
  /// derived from the same live borrowing stream that powers the dashboards,
  /// so they update immediately when a student submits a request.
  List<int> get weeklyActivity {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final weekStart = midnight.subtract(Duration(days: midnight.weekday - 1));
    final totals = List<int>.filled(7, 0);
    final all = [
      ..._activeBorrowings,
      ..._pendingBorrowings,
      ..._overdueBorrowings,
      ..._historyBorrowings,
    ];
    for (final borrowing in all) {
      final requested = borrowing.requestedAt.toLocal();
      final day = DateTime(requested.year, requested.month, requested.day);
      final offset = day.difference(weekStart).inDays;
      if (offset >= 0 && offset < totals.length) {
        totals[offset] += borrowing.quantity;
      }
    }
    return totals;
  }

  List<ActivityEntry> get recentStudentActivity =>
      _activity.where((a) => a.scope == ActivityScope.student).take(3).toList();

  // ── Occupancy (live data from the active_sessions table) ──────────
  // The Mock bundle returns the seed list; the Supabase bundle queries
  // `active_sessions` (joined with `profiles` + `equipment`) and respects
  // RLS so admins see everyone and students see only themselves.
  List<ActiveSession> _activeSessions = const [];
  List<ActiveSession> get activeSessions => List.unmodifiable(_activeSessions);

  StreamSubscription<List<ActiveSession>>? _activeSessionsSubscription;

  int get occupancyCount => _activeSessions.length;
  int get activeOccupancyCount =>
      _activeSessions.where((s) => s.activity == SessionActivity.active).length;
  int get idleOccupancyCount =>
      _activeSessions.where((s) => s.activity == SessionActivity.idle).length;
  int get returningOccupancyCount => _activeSessions
      .where((s) => s.activity == SessionActivity.returning)
      .length;

  /// Admin: forcibly log a user out. Removes the session from the
  /// local cache and (for the Supabase bundle) the corresponding row
  /// in `active_sessions`, then logs the action to the activity feed.
  Future<void> kickSession(String id) async {
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
    try {
      // Delete the *kicked* user's row, not the admin's own. The
      // Supabase bundle gates this on the `is_admin()` RLS policy.
      await bundle.user.removeSessionById(id);
    } catch (_) {
      // Mock bundle is a no-op; Supabase can fail on RLS, but the
      // local removal already gives the admin immediate feedback.
    }
    notifyListeners();
  }

  /// Admin security action from the Login History tab: terminate a
  /// user's live session by profile id. Unlike [kickSession] this does
  /// not require the row to already sit in the local occupancy cache —
  /// the live list is re-fetched first so "is this user online right
  /// now?" is answered from the server, not from a possibly-stale
  /// snapshot. The kick appends a `force_logout` row to
  /// `session_history`, so the history feed is refreshed afterwards and
  /// the kicked device signs itself out via its own presence watcher.
  Future<ForceLogoutOutcome> forceLogoutFromHistory(
    LoginHistoryEntry entry,
  ) async {
    final profileId = entry.profileId;
    if (profileId.isEmpty) return ForceLogoutOutcome.failed;
    // Never let an admin terminate their own session from this flow.
    if (profileId == currentAuthId) return ForceLogoutOutcome.failed;

    try {
      _activeSessions = await bundle.user.getActiveSessions();
    } catch (_) {
      // Fall back to the cached snapshot below.
    }
    final online = _activeSessions.any((s) => s.id == profileId);
    if (!online) return ForceLogoutOutcome.notOnline;

    try {
      await bundle.user.removeSessionById(profileId);
    } catch (_) {
      return ForceLogoutOutcome.failed;
    }

    _activeSessions.removeWhere((s) => s.id == profileId);
    _log(
      scope: ActivityScope.admin,
      icon: Icons.logout_rounded,
      tone: PupColors.signalRed,
      title: 'Forced logout: ${entry.fullName}',
      subtitle: '${entry.studentId} • Terminated from Login History',
    );
    notifyListeners();
    unawaited(loadLoginHistory());
    return ForceLogoutOutcome.terminated;
  }

  /// Fetch the latest live-occupancy feed. Used by the admin's Live
  /// tab on first load and on pull-to-refresh. Safe to call from any
  /// shell — RLS keeps the result scoped to what the caller can see.
  Future<void> loadActiveSessions() async {
    try {
      _activeSessions = await bundle.user.getActiveSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('loadActiveSessions failed: $e');
      // Keep the previous list on error — surface through _error so
      // the shell can show a banner if it cares.
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Self presence (student's own row in active_sessions) ────────────
  // The student no longer manually toggles their presence from the home
  // screen — that "Go online / You're online" card has been removed.
  // The `SessionLifecycleGuard` mounted in `main.dart` still keeps the
  // `active_sessions` row warm in the background (heartbeat + auto-mark
  // on resume), so the admin's *historical* view keeps getting accurate
  // `session_history` rows whenever the student signs out, the app is
  // detached, or the server's expire sweep catches a stale heartbeat.
  // What is gone is the *manual* control surface — no goOnline, no
  // goOffline, no toggle, no presence error to surface.
  //
  // We still expose the read-only `selfSession` / `isSelfOnline` getters
  // because other code (e.g. the admin's login history view, future
  // "currently signed in" indicators) wants to know whether the current
  // user has a live `active_sessions` row without owning the manual
  // toggle UI.

  /// The auth id of the currently signed-in user. The `active_sessions`
  /// table is keyed on this UUID (`profile_id`), not on
  /// `profiles.student_id` (the school number). Resolved through the
  /// repository so the controller doesn't have to import the Supabase
  /// client directly.
  String? get _selfAuthId => bundle.user.currentAuthId;

  /// Public alias for [_selfAuthId] so admin screens can hide destructive
  /// actions (like force logout) that would target the signed-in account
  /// itself.
  String? get currentAuthId => _selfAuthId;

  /// The student's own `ActiveSession`, or null when the row doesn't
  /// exist. Read-only — used by the admin shell's login history view
  /// and other read-side features.
  ActiveSession? get selfSession {
    final me = _selfAuthId;
    if (me == null) return null;
    for (final s in _activeSessions) {
      if (s.id == me) return s;
    }
    return null;
  }

  /// True when the student has a row in `active_sessions`.
  bool get isSelfOnline => selfSession != null;

  // ── Admin login history (session_history + profile + activity) ─────
  // Populated on demand by [loadLoginHistory] — typically once on the
  // admin shell's first mount and again on pull-to-refresh. Backing
  // table is `session_history` (RLS: admin only); see migration 0006
  // and the repository's `getLoginHistory` for the join + activity
  // correlation.

  List<LoginHistoryEntry> _loginHistory = const [];
  List<LoginHistoryEntry> get loginHistory => List.unmodifiable(_loginHistory);

  bool _loginHistoryLoading = false;
  bool get loginHistoryLoading => _loginHistoryLoading;

  /// Most recent error from [loadLoginHistory]. Surfaced in the admin
  /// view as a soft banner — clearing it lets the next refresh decide
  /// whether to re-show the message.
  String? _loginHistoryError;
  String? get loginHistoryError => _loginHistoryError;
  void clearLoginHistoryError() {
    if (_loginHistoryError == null) return;
    _loginHistoryError = null;
    notifyListeners();
  }

  /// Pull every past session the current admin is allowed to see.
  /// `limit` is forwarded to the repository (defaults to 100) so the
  /// admin view can paginate if it ever needs to.
  Future<void> loadLoginHistory({int limit = 100}) async {
    _loginHistoryLoading = true;
    _loginHistoryError = null;
    notifyListeners();
    try {
      _loginHistory = await bundle.user.getLoginHistory(limit: limit);
    } catch (e) {
      debugPrint('loadLoginHistory failed: $e');
      _loginHistoryError = e.toString();
    } finally {
      _loginHistoryLoading = false;
      notifyListeners();
    }
  }

  // ── Load (initial + pull-to-refresh) ───────────────────────────────────

  /// Pull every list the screens need from the bundle in parallel. Safe
  /// to call multiple times — the shells call it once on startup and
  /// again on the RefreshIndicator pull.
  Future<void> load() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        bundle.equipment.getAll(),
        bundle.borrowings.getActive(),
        bundle.borrowings.getPending(),
        bundle.borrowings.getHistory(),
        bundle.borrowings.getOverdue(),
        bundle.notifications.getAll(),
        _loadProfile(),
        _loadActiveSessions(),
      ]);

      _equipment = results[0] as List<Equipment>;
      // Partition the four fetched buckets through the same helper the
      // Realtime subscription uses. Single source of truth for the
      // active / pending / overdue / history split, so the initial load
      // and a Realtime emit can never disagree on what a row belongs to.
      _partitionBorrowings([
        ...results[1] as List<Borrowing>,
        ...results[2] as List<Borrowing>,
        ...results[3] as List<Borrowing>,
        ...results[4] as List<Borrowing>,
      ]);
      _notifications = results[5] as List<AppNotification>;
      _userProfile = results[6] as UserProfile?;
      _activeSessions = results[7] as List<ActiveSession>;

      _recalcUnread();
      _startNotificationSubscription();
      _loading = false;
    } catch (e, st) {
      debugPrint('StudentDashboardController.load failed: $e\n$st');
      _error = e.toString();
      _loading = false;
    } finally {
      notifyListeners();
    }
  }

  /// Keeps the inbox current without requiring a manual pull-to-refresh or
  /// restarting the screen. Supabase emits the initial list too, so this also
  /// closes the small fetch/subscribe timing gap during first load.
  void _startNotificationSubscription() {
    if (_notificationsSubscription != null) return;
    _notificationsSubscription = bundle.notifications.watch().listen(
      (notifications) {
        // The stream hands us a List.unmodifiable(...) — keep our own
        // mutable copy so markRead / delete / restore can mutate it
        // without throwing "Cannot modify an unmodifiable list".
        _notifications = List.of(notifications);
        _recalcUnread();
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification realtime subscription failed: $error');
      },
    );
  }

  /// Subscribes to the `borrowings` Realtime channel. RLS scopes the
  /// stream automatically — students see only their own rows, admins
  /// see everything. The first emit carries the current snapshot, so
  /// the four buckets get populated without waiting for `load()` to
  /// finish its REST round-trip.
  ///
  /// When the device is offline or the WebSocket drops, the Supabase
  /// client auto-reconnects with exponential backoff, so this single
  /// subscription is enough to keep the cross-device UI live for the
  /// lifetime of the controller.
  void _startBorrowingsSubscription() {
    if (_borrowingsSubscription != null) return;
    _borrowingsSubscription = bundle.borrowings.watchAll().listen(
      (all) {
        _partitionBorrowings(all);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Borrowings realtime subscription failed: $error');
      },
    );
  }

  /// Keeps Admin > Live synchronized across devices. Supabase emits an
  /// initial snapshot and every insert, heartbeat update, deletion, and
  /// force-logout, so the page updates without a refresh or app restart.
  void _startActiveSessionsSubscription() {
    if (_activeSessionsSubscription != null) return;
    _activeSessionsSubscription = bundle.user.watchActiveSessions().listen(
      (sessions) {
        _activeSessions = List.of(sessions);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Active-session realtime subscription failed: $error');
      },
    );
  }

  /// Fetches the current borrowings snapshot and republishes it. Cheap
  /// (`select` on the indexed table, joined rows only) and idempotent —
  /// the partition step is pure, so re-running it with the same data is
  /// a no-op except for the `notifyListeners()` call. This is the
  /// fallback path when the Realtime channel is connected but missed
  /// an event (e.g. the WebSocket was idle for a moment, the device
  /// woke from sleep, the user was on a different tab).
  Future<void> _refreshBorrowingsQuietly() async {
    try {
      final all = await bundle.borrowings.watchAllSnapshot();
      if (all.isEmpty &&
          _pendingBorrowings.isEmpty &&
          _activeBorrowings.isEmpty &&
          _overdueBorrowings.isEmpty &&
          _historyBorrowings.isEmpty) {
        // Don't clobber an empty initial state with an empty result
        // from a transient RLS / network failure mid-load.
        return;
      }
      _partitionBorrowings(all);
      notifyListeners();
    } catch (e) {
      // Quiet failure — the next poll (or the realtime event) will
      // catch up. Don't surface this to the UI as an error banner.
      debugPrint('Periodic borrowings refresh failed: $e');
    }
  }

  /// Public hook so admin screens can force a refresh on demand (e.g.
  /// from a pull-to-refresh or an explicit refresh button) without
  /// waiting for the next periodic tick.
  Future<void> refreshBorrowings() => _refreshBorrowingsQuietly();

  /// Splits a flat list of borrowings into the four status buckets the
  /// UI expects. Called from both the initial `load()` and the Realtime
  /// subscription, so the partitioning logic only lives in one place.
  void _partitionBorrowings(List<Borrowing> all) {
    _activeBorrowings = all
        .where((b) => b.status == BorrowingStatus.active)
        .toList(growable: false);
    _pendingBorrowings = all
        .where((b) => b.status == BorrowingStatus.pending)
        .toList(growable: false);
    _overdueBorrowings = all
        .where((b) => b.status == BorrowingStatus.overdue)
        .toList(growable: false);
    _historyBorrowings = all
        .where(
          (b) =>
              b.status == BorrowingStatus.returned ||
              b.status == BorrowingStatus.rejected,
        )
        .toList(growable: false);
  }

  /// Wrapped in a separate function so a single failing call doesn't
  /// break the whole load() — the rest of the dashboard is still useful
  /// even if the user profile can't be loaded.
  Future<UserProfile?> _loadProfile() async {
    try {
      return await bundle.user.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  /// Same idea as `_loadProfile` for the live-occupancy feed: a single
  /// failure (e.g. RLS deny because the caller isn't an admin) should
  /// surface an empty list rather than blowing up the rest of the load.
  Future<List<ActiveSession>> _loadActiveSessions() async {
    try {
      return await bundle.user.getActiveSessions();
    } catch (_) {
      return const [];
    }
  }

  // ── CRUD: Borrowings ───────────────────────────────────────────────────

  /// Submit a new borrow request. Inserts a `pending` row into Supabase,
  /// moves it to the top of `_pendingBorrowings`, and logs the activity.
  /// Returns the freshly-created borrowing so the caller can pop the
  /// confirmation sheet and show a success snackbar referencing the row
  /// id.
  Future<Borrowing> requestBorrowing(
    Equipment equipment, {
    int quantity = 1,
    String? purpose,
  }) async {
    try {
      final created = await bundle.borrowings.create(
        equipmentId: equipment.id,
        quantity: quantity,
        purpose: purpose,
      );
      _pendingBorrowings = [created, ..._pendingBorrowings];
      _log(
        scope: ActivityScope.student,
        icon: Icons.outbox_rounded,
        tone: PupColors.cyberAmber,
        title: 'Requested: ${created.quantity}× ${created.equipmentName}',
        subtitle: purpose == null || purpose.isEmpty
            ? 'Awaiting admin approval'
            : '"$purpose" — awaiting admin approval',
      );
      notifyListeners();
      return created;
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI (e.g.
      // the borrow confirm sheet). Don't pollute the shell banner with
      // the raw exception — just log it for debugging.
      debugPrint('action failed: $e');
      rethrow;
    }
  }

  /// Student taps "return": moves the loan to the intermediate
  /// `returnRequested` state. Inventory is NOT credited yet — an admin
  /// must verify the physical hand-in via [confirmReturnBorrowing]
  /// (migration 0014). The row stays visible in the active list with a
  /// "return pending" badge until then.
  Future<bool> returnBorrowing(String id) async {
    try {
      await bundle.borrowings.returnBorrowing(id);
      // Re-fetch the single borrowing's new shape so the local list matches
      // what the DB now has. Cheaper than a full reload.
      final updated = await bundle.borrowings.getById(id);
      if (updated == null) return false;
      if (updated.status == BorrowingStatus.returned) {
        // Mock bundle (or legacy backend): return is final immediately.
        _activeBorrowings = _activeBorrowings.where((b) => b.id != id).toList();
        _overdueBorrowings = _overdueBorrowings
            .where((b) => b.id != id)
            .toList();
        _historyBorrowings = [updated, ..._historyBorrowings];
        _log(
          scope: ActivityScope.student,
          icon: Icons.assignment_return_rounded,
          tone: PupColors.mintGreen,
          title: 'Returned: ${updated.equipmentName}',
          subtitle: 'On time • Thank you!',
        );
      } else {
        // Supabase bundle: awaiting admin verification. Keep it in the
        // active bucket so the student sees its "awaiting verification"
        // badge instead of thinking the item vanished.
        _activeBorrowings = [
          updated,
          ..._activeBorrowings.where((b) => b.id != id),
        ];
        _overdueBorrowings = _overdueBorrowings
            .where((b) => b.id != id)
            .toList();
        _log(
          scope: ActivityScope.student,
          icon: Icons.assignment_return_rounded,
          tone: PupColors.cyberAmber,
          title: 'Return requested: ${updated.equipmentName}',
          subtitle: 'Awaiting admin verification',
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI (e.g.
      // snackbars from the admin screens). Don't pollute the shell
      // banner with the raw exception — just log it.
      debugPrint('action failed: $e');
      return false;
    }
  }

  /// Admin verifies the physical return of a loan or a pending return
  /// request. This is the transition that credits inventory on the
  /// backend (migration 0014). Moves the borrowing into history with
  /// status=returned.
  Future<bool> confirmReturnBorrowing(String id) async {
    try {
      await bundle.borrowings.confirmReturn(id);
      final updated = await bundle.borrowings.getById(id);
      if (updated == null) return false;
      _activeBorrowings = _activeBorrowings.where((b) => b.id != id).toList();
      _overdueBorrowings = _overdueBorrowings.where((b) => b.id != id).toList();
      _historyBorrowings = [updated, ..._historyBorrowings];
      _log(
        scope: ActivityScope.admin,
        icon: Icons.verified_rounded,
        tone: PupColors.mintGreen,
        title: 'Return verified: ${updated.equipmentName}',
        subtitle: '${updated.studentName} • ${updated.studentId}',
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('action failed: $e');
      return false;
    }
  }

  /// Admin: approves a pending request. Moves it from `pendingBorrowings`
  /// to `activeBorrowings` with status=active. The original return date
  /// is preserved.
  Future<bool> approveBorrowing(String id) async {
    try {
      await bundle.borrowings.approve(id);
      final updated = await bundle.borrowings.getById(id);
      if (updated == null) return false;
      _pendingBorrowings = _pendingBorrowings.where((b) => b.id != id).toList();
      _activeBorrowings = [updated, ..._activeBorrowings];
      _log(
        scope: ActivityScope.admin,
        icon: Icons.check_circle_rounded,
        tone: PupColors.mintGreen,
        title: 'Approved: ${updated.equipmentName}',
        subtitle: '${updated.studentName} • ${updated.studentId}',
      );
      notifyListeners();
      return true;
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
      return false;
    }
  }

  /// Admin: rejects a pending request. Moves it from `pendingBorrowings`
  /// to `historyBorrowings` with status=rejected.
  Future<bool> rejectBorrowing(String id) async {
    try {
      await bundle.borrowings.reject(id);
      final updated = await bundle.borrowings.getById(id);
      if (updated == null) return false;
      _pendingBorrowings = _pendingBorrowings.where((b) => b.id != id).toList();
      _historyBorrowings = [updated, ..._historyBorrowings];
      _log(
        scope: ActivityScope.admin,
        icon: Icons.cancel_rounded,
        tone: PupColors.signalRed,
        title: 'Rejected: ${updated.equipmentName}',
        subtitle: '${updated.studentName} • ${updated.studentId}',
      );
      notifyListeners();
      return true;
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
      return false;
    }
  }

  // ── CRUD: Equipment likes (currently a no-op against the DB) ──────────

  /// `toggleLike` persists to the DB once you add a `favorites` table.
  /// For now it's a local-only state flip — the mock controller had the
  /// same behaviour.
  void toggleLike(Equipment equipment) {
    _equipment = _equipment
        .map((e) => e.id == equipment.id ? e.copyWith(isLiked: !e.isLiked) : e)
        .toList();
    notifyListeners();
  }

  // ── CRUD: Notifications ───────────────────────────────────────────────

  Future<void> markRead(String id) async {
    try {
      await bundle.notifications.markRead(id);
      final i = _notifications.indexWhere((n) => n.id == id);
      if (i != -1) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        _recalcUnread();
        notifyListeners();
      }
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await bundle.notifications.markAllRead();
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _recalcUnread();
      notifyListeners();
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await bundle.notifications.clearAll();
      _notifications = [];
      _recalcUnread();
      notifyListeners();
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await bundle.notifications.delete(id);
      _notifications.removeWhere((n) => n.id == id);
      _recalcUnread();
      notifyListeners();
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
    }
  }

  /// Re-inserts a previously deleted notification. The bundle's
  /// `restore` method does the actual insert.
  Future<void> restoreNotification(AppNotification n) async {
    try {
      await bundle.notifications.restore(n);
      _notifications.insert(0, n);
      _recalcUnread();
      notifyListeners();
    } catch (e) {
      // User-action errors are surfaced by the caller's own UI. Don't
      // pollute the shell banner with the raw exception — just log it.
      debugPrint('action failed: $e');
    }
  }

  void _recalcUnread() {
    _unread = _notifications.where((n) => !n.isRead).length;
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
    while (_activity.length > 30) {
      _activity.removeLast();
    }
  }

  // ── Search (still client-side after the load) ────────────────────────
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

    // Simulated network latency keeps the UI feeling real even when
    // the query is answered locally.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      _filtered = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    final queryLower = trimmed.toLowerCase();
    final openIds = openRequestEquipmentIds;
    _filtered = _equipment.where((e) {
      final inText =
          e.name.toLowerCase().contains(queryLower) ||
          e.id.toLowerCase().contains(queryLower);
      final inCategory = _selectedCategory == 'All'
          ? true
          : e.category == _selectedCategory;
      return inText && inCategory && !openIds.contains(e.id);
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

  // ── Tickers + dispose ────────────────────────────────────────────────
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _borrowingsRefreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _notificationsSubscription?.cancel();
    _borrowingsSubscription?.cancel();
    _activeSessionsSubscription?.cancel();
    super.dispose();
  }
}
