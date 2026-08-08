import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
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
      'id, equipment_id, student_id, status, purpose, requested_at, '
      'borrowed_at, due_at, returned_at, '
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
    final returnedAt = DateTime.tryParse((row['returned_at'] as String?) ?? '');

    final borrowDate = borrowedAt ?? requestedAt ?? DateTime.now();
    final returnDate = returnedAt ?? dueAt ?? borrowDate;

    return Borrowing(
      id: row['id'] as String,
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      studentId: studentNumber,
      studentName: studentName,
      purpose: (row['purpose'] as String?) ?? '',
      borrowDate: borrowDate,
      returnDate: returnDate,
      status: _parseStatus((row['status'] as String?) ?? 'pending'),
      borrowedByYou: true,
      // The QR code on the prototype just round-trips the borrowing id; once
      // a real QR generator is wired up this would be the encoded payload.
      qrCode: row['id'] as String,
    );
  }

  static BorrowingStatus _parseStatus(String raw) {
    switch (raw) {
      case 'pending':
        return BorrowingStatus.pending;
      case 'approved':
      case 'active':
        return BorrowingStatus.active;
      case 'overdue':
        return BorrowingStatus.overdue;
      case 'returned':
        return BorrowingStatus.returned;
      case 'rejected':
        return BorrowingStatus.rejected;
      default:
        return BorrowingStatus.pending;
    }
  }

  Future<List<Borrowing>> _listByStatus(String status) async {
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .eq('status', status)
        .order('requested_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<Borrowing>> _listAllWithJoins() async {
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .order('requested_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<Borrowing>> getActive() => _listByStatus('active');

  @override
  Future<List<Borrowing>> getOverdue() => _listByStatus('overdue');

  @override
  Future<List<Borrowing>> getPending() => _listByStatus('pending');

  @override
  Future<List<Borrowing>> getHistory() async {
    // "History" is everything that's terminal — returned or rejected.
    final rows = await _client
        .from('borrowings')
        .select(_selectWithJoins)
        .inFilter('status', ['returned', 'rejected'])
        .order('returned_at', ascending: false);
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

  @override
  Future<Borrowing> create({
    required String equipmentId,
    String? purpose,
  }) async {
    final row = await _client.rpc(
      'request_borrowing',
      params: {'p_equipment_id': equipmentId, 'p_purpose': purpose ?? ''},
    );
    return _loadRpcBorrowing(row);
  }

  @override
  Future<void> returnBorrowing(String id) async {
    await _client.rpc(
      'transition_borrowing',
      params: {'p_borrowing_id': id, 'p_action': 'request_return'},
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

  Future<Borrowing> _loadRpcBorrowing(dynamic row) async {
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
