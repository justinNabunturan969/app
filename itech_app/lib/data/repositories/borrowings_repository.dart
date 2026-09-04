import '../../student/mock_data.dart';
import '../../student/models.dart';

/// Contract for all borrowing data — the four buckets (active / overdue /
/// pending / history) plus the admin + student actions on them.
///
/// Today: holds mutable in-memory lists seeded from `StudentMockData`.
/// Tomorrow: `FirebaseBorrowingsRepository` queries the `borrowings`
/// Firestore collection (one document per borrowing) and writes
/// status changes back via `FirebaseFirestore.runTransaction`.
abstract class BorrowingsRepository {
  // ── Reads ───────────────────────────────────────────────────────────
  Future<List<Borrowing>> getActive();
  Future<List<Borrowing>> getOverdue();
  Future<List<Borrowing>> getPending();
  Future<List<Borrowing>> getHistory();
  Future<Borrowing?> getById(String id);

  /// Live feed of every borrowing visible to the current user. Re-emits
  /// the full list whenever a row is inserted, updated, or deleted on the
  /// `borrowings` table. RLS does the scoping automatically — students
  /// see only their own, admins see all. The mock implementation returns
  /// an empty stream (the controller manages its own in-memory state for
  /// the offline demo).
  Stream<List<Borrowing>> watchAll();

  /// One-shot snapshot of every borrowing visible to the current user
  /// (same RLS scope as `watchAll`). Used by the periodic poll and by
  /// manual pull-to-refresh — both want a fresh "now" view without
  /// subscribing to a stream. Falls back to the in-memory state in
  /// the mock implementation.
  Future<List<Borrowing>> watchAllSnapshot();

  // ── Student actions ─────────────────────────────────────────────────
  /// Create a new pending borrowing request. Returns the freshly-inserted
  /// row so the controller can move it into `pendingBorrowings` without
  /// re-fetching the whole list.
  Future<Borrowing> create({
    required String equipmentId,
    required int quantity,
    String? purpose,
    String? room,
  });

  Future<void> returnBorrowing(String id);

  /// Student: withdraw a still-pending request. Frees the
  /// one-open-request-per-item slot immediately so the item can be
  /// re-requested without waiting for an admin (migration 0024).
  Future<void> cancelPending(String id);

  /// Admin: verify the physical return of a loan (or a pending return
  /// request). Records the [condition] and optional [notes] as part of
  /// the audit trail (migration 0034). `condition` must be one of
  /// 'good', 'damaged', or 'needs_repair'.
  Future<void> confirmReturn(
    String id, {
    required String condition,
    String? notes,
  });

  /// Admin: refuse a student's return request. The borrowing moves
  /// back from `return_requested` to `active` and inventory is
  /// re-debited (the student did not actually hand the item back).
  /// [notes] are stored on the row as part of the audit trail.
  Future<void> rejectReturn(String id, {String? notes});

  // ── Admin actions ───────────────────────────────────────────────────
  Future<void> approve(String id);
  Future<void> reject(String id);
}

/// Mock implementation — keeps the four lists in memory and mutates
/// them when the admin or student takes an action. Identical
/// behaviour to the previous in-controller implementation.
class MockBorrowingsRepository implements BorrowingsRepository {
  MockBorrowingsRepository()
    : _active = List.of(StudentMockData.activeBorrowings),
      _overdue = List.of(StudentMockData.overdueBorrowings),
      _pending = List.of(StudentMockData.pendingBorrowings),
      _history = List.of(StudentMockData.historyBorrowings);

  final List<Borrowing> _active;
  final List<Borrowing> _overdue;
  final List<Borrowing> _pending;
  final List<Borrowing> _history;

  @override
  Future<List<Borrowing>> getActive() async => List.unmodifiable(_active);

  @override
  Future<List<Borrowing>> getOverdue() async => List.unmodifiable(_overdue);

  @override
  Future<List<Borrowing>> getPending() async => List.unmodifiable(_pending);

  @override
  Future<List<Borrowing>> getHistory() async => List.unmodifiable(_history);

  @override
  Future<Borrowing?> getById(String id) async {
    Borrowing? find(List<Borrowing> list) {
      for (final b in list) {
        if (b.id == id) return b;
      }
      return null;
    }

    return find(_active) ?? find(_overdue) ?? find(_pending) ?? find(_history);
  }

  @override
  Stream<List<Borrowing>> watchAll() => const Stream.empty();

  @override
  Future<List<Borrowing>> watchAllSnapshot() async {
    return [..._active, ..._overdue, ..._pending, ..._history];
  }

  // ── Student: create a new pending request ─────────────────────────
  @override
  Future<Borrowing> create({
    required String equipmentId,
    required int quantity,
    String? purpose,
    String? room,
  }) async {
    // The mock has no concept of "current student" — fall back to the
    // seed student so the created borrowing shows up with a believable
    // owner on every screen.
    final equipmentList = StudentMockData.equipment;
    Equipment? equipment;
    for (final e in equipmentList) {
      if (e.id == equipmentId) {
        equipment = e;
        break;
      }
    }

    final now = DateTime.now();
    final due = now.add(const Duration(days: 3));
    final newBorrowing = Borrowing(
      id: 'B-${now.millisecondsSinceEpoch}',
      equipmentId: equipmentId,
      equipmentName: equipment?.name ?? 'Unknown item',
      purpose: purpose ?? '',
      room: room ?? '',
      borrowDate: now,
      returnDate: due,
      status: BorrowingStatus.pending,
      borrowedByYou: true,
      qrCode: 'B-${now.millisecondsSinceEpoch}',
      quantity: quantity,
    );

    _pending.insert(0, newBorrowing);
    return newBorrowing;
  }

  // ── Student: return an active or overdue loan ──────────────────────
  @override
  Future<void> returnBorrowing(String id) async {
    Borrowing? found;
    final i = _active.indexWhere((b) => b.id == id);
    if (i != -1) {
      found = _active.removeAt(i);
    } else {
      final j = _overdue.indexWhere((b) => b.id == id);
      if (j != -1) {
        found = _overdue.removeAt(j);
      }
    }
    if (found != null) {
      _history.insert(
        0,
        found.copyWith(
          status: BorrowingStatus.returned,
          returnDate: DateTime.now(),
        ),
      );
    }
  }

  // ── Admin: verify a physical return ────────────────────────────────
  @override
  Future<void> confirmReturn(
    String id, {
    required String condition,
    String? notes,
  }) async {
    // The mock treats the student's return tap as final (no verification
    // step offline), so this only needs to catch loans still sitting in
    // the active/overdue lists. The condition / notes are accepted for
    // API parity with the Supabase implementation but ignored in-memory.
    await returnBorrowing(id);
  }

  // ── Admin: reject a return request ─────────────────────────────────
  @override
  Future<void> rejectReturn(String id, {String? notes}) async {
    // The mock doesn't track inventory counts, so we just flip the
    // status from return_requested back to active and stash the admin
    // notes on the row. The Supabase implementation handles the
    // inventory re-debit through the transition_borrowing RPC.
    Borrowing? found;
    List<List<Borrowing>> buckets = [_active, _overdue, _pending, _history];
    outer:
    for (final list in buckets) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == id) {
          found = list.removeAt(i);
          break outer;
        }
      }
    }
    if (found == null) return;
    _active.insert(
      0,
      found.copyWith(
        status: BorrowingStatus.active,
        returnNotes: (notes != null && notes.isNotEmpty)
            ? notes
            : found.returnNotes,
      ),
    );
  }

  // ── Admin: approve a pending request ───────────────────────────────
  @override
  Future<void> approve(String id) async {
    final i = _pending.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final found = _pending.removeAt(i);
    _active.insert(
      0,
      found.copyWith(
        status: BorrowingStatus.active,
        borrowDate: DateTime.now(),
      ),
    );
  }

  // ── Admin: reject a pending request ───────────────────────────────
  @override
  Future<void> reject(String id) async {
    final i = _pending.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final found = _pending.removeAt(i);
    _history.insert(
      0,
      found.copyWith(
        status: BorrowingStatus.rejected,
        returnDate: DateTime.now(),
      ),
    );
  }

  // ── Student: withdraw a pending request ───────────────────────────
  @override
  Future<void> cancelPending(String id) async {
    final i = _pending.indexWhere((b) => b.id == id);
    if (i == -1) return;
    final found = _pending.removeAt(i);
    _history.insert(
      0,
      found.copyWith(status: BorrowingStatus.cancelled),
    );
  }
}
