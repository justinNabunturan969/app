import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../borrowings_repository.dart';

/// Supabase-backed borrowings repository. The four read buckets map to a
/// single `borrowings` table with a `status` column; the write methods
/// update the status with the right transition.
class SupabaseBorrowingsRepository implements BorrowingsRepository {
  SupabaseBorrowingsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// Joins the equipment row so the model carries the equipment's display
  /// name. Uses PostgREST embedded resources via `equipment:equipment_id(...)`.
  static const _selectWithEquipment =
      'id, equipment_id, status, purpose, requested_at, borrowed_at, '
      'due_at, returned_at, '
      'equipment:equipment_id ( id, name )';

  static Borrowing _fromRow(Map<String, dynamic> row) {
    final equipment = row['equipment'] as Map<String, dynamic>?;
    final equipmentName = (equipment?['name'] as String?) ?? 'Unknown item';
    final equipmentId = (row['equipment_id'] as String?) ?? '';

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
        .select(_selectWithEquipment)
        .eq('status', status)
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
        .select(_selectWithEquipment)
        .inFilter('status', ['returned', 'rejected'])
        .order('returned_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<Borrowing?> getById(String id) async {
    final row = await _client
        .from('borrowings')
        .select(_selectWithEquipment)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
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
