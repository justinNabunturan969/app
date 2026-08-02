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
    final requestedAt = DateTime.tryParse((row['requested_at'] as String?) ?? '');
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
  Future<void> returnBorrowing(String id) async {
    await _client.from('borrowings').update({
      'status': 'returned',
      'returned_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> approve(String id) async {
    final now = DateTime.now();
    // 3-day default loan period. Wire this to your real policy later.
    final due = now.add(const Duration(days: 3));
    await _client.from('borrowings').update({
      'status': 'active',
      'approved_at': now.toIso8601String(),
      'borrowed_at': now.toIso8601String(),
      'due_at': due.toIso8601String(),
      'approved_by': _client.auth.currentUser?.id,
    }).eq('id', id);
  }

  @override
  Future<void> reject(String id) async {
    await _client.from('borrowings').update({
      'status': 'rejected',
      'returned_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
