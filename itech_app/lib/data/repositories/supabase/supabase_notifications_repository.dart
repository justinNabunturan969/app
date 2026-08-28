import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../auth_exceptions.dart';
import '../notifications_repository.dart';

/// Supabase-backed notifications feed. Each row is owned by a single
/// `recipient_id` (the student's profile id), and RLS ensures no one else
/// can read or mutate them.
class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  static AppNotification _fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      message: (row['body'] as String?) ?? '',
      type: _parseType((row['type'] as String?) ?? 'reminder'),
      timestamp:
          DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      isRead: (row['is_read'] as bool?) ?? false,
      // Migration 0035 stamps this on the return-related notifications
      // (admin 'Return to confirm' + student 'Return confirmed') so the
      // UI can deep-link straight to the borrowing. Null for everything
      // else — backward compatible with rows written before the column
      // existed.
      relatedBorrowingId: row['related_borrowing_id'] as String?,
    );
  }

  static NotificationType _parseType(String raw) {
    switch (raw) {
      case 'approved':
        return NotificationType.approved;
      case 'rejected':
        return NotificationType.rejected;
      case 'overdue':
        return NotificationType.overdue;
      case 'returned':
        return NotificationType.returned;
      case 'new_item':
        return NotificationType.newItem;
      case 'reminder':
      default:
        return NotificationType.reminder;
    }
  }

  @override
  Future<List<AppNotification>> getAll() async {
    if (_client.auth.currentUser == null) {
      throw const NotSignedInException('getAll');
    }
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        // The inbox only renders the newest entries; without a cap this
        // query ships EVERY notification ever received and grows forever.
        .limit(200);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Stream<List<AppNotification>> watch() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid)
        .map((rows) {
          final notifications = rows.map(_fromRow).toList();
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return List<AppNotification>.unmodifiable(notifications);
        });
  }

  @override
  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  @override
  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotSignedInException('markAllRead');
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', uid)
        .eq('is_read', false);
  }

  @override
  Future<void> clearAll() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotSignedInException('clearAll');
    await _client.from('notifications').delete().eq('recipient_id', uid);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  @override
  Future<void> restore(AppNotification n) async {
    // "Restore" maps to an insert in the DB. Only the fields we can
    // actually write are populated — recipient_id is set from the current
    // session so the row lands in the right inbox.
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotSignedInException('restore');
    await _client.from('notifications').insert({
      'recipient_id': uid,
      'type': _typeToString(n.type),
      'title': n.title,
      'body': n.message,
      'is_read': n.isRead,
    });
  }

  static String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.approved:
        return 'approved';
      case NotificationType.rejected:
        return 'rejected';
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.overdue:
        return 'overdue';
      case NotificationType.newItem:
        return 'new_item';
      case NotificationType.returned:
        return 'returned';
    }
    // The switch above is exhaustive over the enum, so this line is
    // unreachable at runtime. Throwing keeps Dart's flow analysis happy
    // without us faking a return value.
    // ignore: dead_code
    throw StateError('Unhandled NotificationType: $t');
  }
}
