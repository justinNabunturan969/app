import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../auth_exceptions.dart';
import '../borrowings_repository.dart';

/// Supabase-backed borrowings repository. The four read buckets map to a
/// single `borrowings` table with a `status` column; the write methods
/// update the status with the right transition.
class SupabaseBorrowingsRepository implements BorrowingsRepository {
  SupabaseBorrowingsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// Joins the equipment and the student (profiles) rows so the model
  /// carries display names instead of falling back to its hardcoded
  /// placeholder defaults. The FK hints make the relation names unambiguous
  /// to PostgREST. `student` is an alias for the embedded `profiles` row;
  /// its `student_id` field is the school number, not the FK UUID.
  static const _selectWithJoins =
      'id, equipment_id, student_id, status, purpose, quantity, room, requested_at, '
      'borrowed_at, due_at, returned_at, '
      'return_condition, return_notes, confirmed_by, confirmed_at, '
      'equipment:equipment!borrowings_equipment_id_fkey ( id, name ), '
      'student:profiles!borrowings_student_id_fkey ( id, student_id, full_name )';

  static Borrowing _fromRow(Map<String, dynamic> row) {
    final equipment = row['equipment'];
    final equipmentName = (equipment is Map && equipment['name'] is String)
        ? equipment['name'] as String
        : 'Unknown item';
    final equipmentId = (row['equipment_id'] as String?) ?? '';

    // `student` is the embedded `profiles` row (see _selectWithJoins).
    // The text `student_id` inside it is the school number, not the FK
    // UUID — the UUID is `student['id']`.
    final student = row['student'];
    String studentName = 'Unknown student';
    String studentNumber = '';
    if (student is Map) {
      final rawName = student['full_name'];
      if (rawName is String && rawName.trim().isNotEmpty) {
        studentName = rawName;
      }
      final rawNumber = student['student_id'];
      if (rawNumber is String) studentNumber = rawNumber;
    }

    // Pick whichever timestamp the row has. Pending requests have only
    // requested_at, active loans have borrowed_at/due_at, history has
    // returned_at.
    final requestedAt = DateTime.tryParse(
      (row['requested_at'] as String?) ?? '',
    );
    final borrowedAt = DateTime.tryParse((row['borrowed_at'] as String?) ?? '');
    final dueAt = DateTime.tryParse((row['due_at'] as String?) ?? '');
    var returnedAt = DateTime.tryParse((row['returned_at'] as String?) ?? '');
    final confirmedAt = DateTime.tryParse((row['confirmed_at'] as String?) ?? '');

    final status = _parseStatus((row['status'] as String?) ?? 'pending');

    // A rejected request was never borrowed, so it has no return date —
    // ignore any stray `returned_at` (older deployments stamped it on
    // reject) so history doesn't display a fake return date. Same for a
    // student-cancelled request (migration 0024): nothing was borrowed.
    if (status == BorrowingStatus.rejected ||
        status == BorrowingStatus.cancelled ||
        status == BorrowingStatus.pending) {
      returnedAt = null;
    }

    final borrowDate = borrowedAt ?? requestedAt ?? DateTime.now();
    final returnDate = returnedAt ?? dueAt ?? borrowDate;

    return Borrowing(
      id: row['id'] as String,
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      studentId: studentNumber,
      studentName: studentName,
      purpose: (row['purpose'] as String?) ?? '',
      room: (row['room'] as String?) ?? '',
      borrowDate: borrowDate,
      returnDate: returnDate,
      status: status,
      borrowedByYou: true,
      // The QR code on the prototype just round-trips the borrowing id; once
      // a real QR generator is wired up this would be the encoded payload.
      qrCode: row['id'] as String,
      quantity: (row['quantity'] as int?) ?? 1,
      requestedAt: requestedAt ?? borrowDate,
      returnCondition: row['return_condition'] as String?,
      returnNotes: row['return_notes'] as String?,
      confirmedBy: row['confirmed_by'] as String?,
      confirmedAt: confirmedAt,
    );
  }

  static BorrowingStatus _parseStatus(String raw) {
    switch (raw) {
      case 'pending':
        return BorrowingStatus.pending;
      case 'approved':
      case 'active':
        return BorrowingStatus.active;
      case 'return_requested':
        return BorrowingStatus.returnRequested;
      case 'overdue':
        return BorrowingStatus.overdue;
      case 'returned':
        return BorrowingStatus.returned;
      case 'rejected':
        return BorrowingStatus.rejected;
      case 'cancelled':
        return BorrowingStatus.cancelled;
      default:
        return BorrowingStatus.pending;
    }
  }

  Future<List<Borrowing>> _listByStatuses(List<String> statuses) async {
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .inFilter('status', statuses)
        .order('requested_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<Borrowing>> _listAllWithJoins() async {
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        // Newest first, hard-capped. This runs on every realtime event AND
        // on the admin's 15-second poll; without a cap the payload grows
        // with the full history of the table. 500 covers every live bucket
        // plus recent history many times over.
        .order('requested_at', ascending: false)
        .limit(500);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<Borrowing>> getActive() =>
      // 'approved' is a legacy status that maps to BorrowingStatus.active;
      // include it so such rows don't vanish from every bucket.
      _listByStatuses(['approved', 'active', 'return_requested']);

  @override
  Future<List<Borrowing>> getOverdue() => _listByStatuses(['overdue']);

  @override
  Future<List<Borrowing>> getPending() => _listByStatuses(['pending']);

  @override
  Future<List<Borrowing>> getHistory() async {
    // "History" is everything terminal — returned, rejected, or cancelled by
    // the student (0024). Cancelled requests previously vanished from every
    // bucket, so they are included here; _fromRow strips their fake return
    // date. Ordered by request time (terminal rows may lack returned_at) and
    // hard-capped so the payload stays bounded as history accumulates.
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .inFilter('status', ['returned', 'rejected', 'cancelled'])
        .order('requested_at', ascending: false)
        .limit(300);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<Borrowing?> getById(String id) async {
    final row = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Live feed of every borrowing visible to the current user. The
  /// Supabase Realtime emits plain `borrowings` rows, which cannot include
  /// PostgREST relationship joins. Use those events only as an invalidation
  /// signal, then reload a joined snapshot so the admin UI keeps the real
  /// equipment and student names.
  ///
  /// The migration `0001_initial_schema.sql` already added `borrowings` to
  /// the `supabase_realtime` publication, so no further DB work is needed
  /// — this method just subscribes to the existing channel.
  ///
  /// Returns an empty stream when the user is signed out so callers don't
  /// have to special-case the unauthenticated state.
  @override
  Stream<List<Borrowing>> watchAll() {
    if (_client.auth.currentUser == null) {
      return const Stream.empty();
    }
    return _client
        .from('borrowings')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => _listAllWithJoins());
  }

  /// One-shot refresh — same join + RLS scope as the realtime stream,
  /// but synchronous (one query, one response). The controller's
  /// 15-second poll calls this so the admin's queue is never more than
  /// 15s stale even if a realtime event is dropped on the floor.
  ///
  /// Throws [NotSignedInException] when signed out instead of returning
  /// an empty list, so "no borrowings yet" is distinguishable from
  /// "the session expired".
  @override
  Future<List<Borrowing>> watchAllSnapshot() {
    if (_client.auth.currentUser == null) {
      throw const NotSignedInException('watchAllSnapshot');
    }
    return _listAllWithJoins();
  }

  @override
  Future<Borrowing> create({
    required String equipmentId,
    required int quantity,
    String? purpose,
    String? room,
  }) async {
    final row = await _client.rpc(
      'request_borrowing',
      params: {
        'p_equipment_id': equipmentId,
        'p_purpose': purpose ?? '',
        'p_quantity': quantity,
        'p_room': room,
      },
    );
    return _loadRpcBorrowing(row);
  }

  /// Student taps "return": the borrowing moves into the `return_requested`
  /// intermediate state. Inventory is credited at this step (migration 0032)
  /// so the item is borrowable again immediately and the same student can
  /// re-request it. The admin's `confirmReturn` later just finalises the
  /// closure (`return_requested` -> `returned`) without touching the count.
  @override
  Future<void> returnBorrowing(String id) async {
    await _client.rpc(
      'transition_borrowing',
      params: {'p_borrowing_id': id, 'p_action': 'request_return'},
    );
  }

  /// Admin-only: verify the physical return of a loan. The inventory was
  /// already credited when the student submitted the return request
  /// (migration 0032), so this is now a pure status transition. The
  /// [condition] (required) and [notes] (optional) are recorded on the
  /// borrowing as part of the audit trail (migration 0034).
  @override
  Future<void> confirmReturn(
    String id, {
    required String condition,
    String? notes,
  }) async {
    await _client.rpc(
      'transition_borrowing',
      params: {
        'p_borrowing_id': id,
        'p_action': 'confirm_return',
        'p_condition': condition,
        'p_notes': notes,
      },
    );
  }

  /// Admin-only: refuse a student's return request. The borrowing flips
  /// from `return_requested` back to `active` and inventory is
  /// re-debited (the student never actually handed the item back).
  /// [notes] are stored as part of the audit trail.
  ///
  /// **Server-side requirements**:
  /// 1. `transition_borrowing` must accept `p_action = 'reject_return'`
  ///    (mirror of `request_return`): status `return_requested` → `active`
  ///    and decrement `equipment.available_count` by the borrowing's
  ///    quantity.
  /// 2. The same RPC should insert a `notifications` row for the
  ///    student with `type = 'rejected'` and a body that includes
  ///    `p_notes` so the student sees *why* their return was refused
  ///    in the inbox. The realtime subscription in the student shell
  ///    picks it up automatically.
  @override
  Future<void> rejectReturn(String id, {String? notes}) async {
    await _client.rpc(
      'transition_borrowing',
      params: {
        'p_borrowing_id': id,
        'p_action': 'reject_return',
        'p_notes': notes,
      },
    );
  }

  @override
  Future<void> approve(String id) async {
    await _client.rpc(
      'transition_borrowing',
      params: {'p_borrowing_id': id, 'p_action': 'approve'},
    );
  }

  @override
  Future<void> reject(String id) async {
    await _client.rpc(
      'transition_borrowing',
      params: {'p_borrowing_id': id, 'p_action': 'reject'},
    );
  }

  @override
  Future<void> cancelPending(String id) async {
    await _client.rpc(
      'transition_borrowing',
      params: {'p_borrowing_id': id, 'p_action': 'cancel'},
    );
  }

  Future<Borrowing> _loadRpcBorrowing(dynamic row) async {
    // Migration 0029 RPCs return an ENRICHED jsonb payload (equipment +
    // student embedded, same shape as _selectWithJoins), so we can build the
    // model straight from the response — no second round-trip per action.
    if (row is Map && row['equipment'] is Map) {
      return _fromRow(Map<String, dynamic>.from(row));
    }
    // Older server deployment (pre-0029): the RPC returned a bare borrowing
    // row without joins, so resolve the display names via getById once.
    final id = switch (row) {
      {'id': final String id} => id,
      [{'id': final String id}, ...] => id,
      _ => null,
    };
    if (id == null) throw StateError('Borrowing action returned no record.');
    final borrowing = await getById(id);
    if (borrowing == null) throw StateError('Borrowing record was not found.');
    return borrowing;
  }
}
