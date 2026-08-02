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

  // ── Student actions ─────────────────────────────────────────────────
  Future<void> returnBorrowing(String id);

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
}
