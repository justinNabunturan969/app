import '../../student/mock_data.dart';
import '../../student/models.dart';

/// Contract for the notifications feed.
///
/// Today: holds a mutable in-memory list seeded from
/// `StudentMockData.notifications`.
/// Tomorrow: `FirebaseNotificationsRepository` subscribes to a
/// `notifications` Firestore collection per user with `.snapshots()`
/// so new approvals, reminders, and overdue alerts appear in real time.
abstract class NotificationsRepository {
  Future<List<AppNotification>> getAll();

  /// Emits the complete inbox whenever Supabase Realtime observes a change.
  /// The controller owns the subscription and updates the UI immediately.
  Stream<List<AppNotification>> watch();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> clearAll();
  Future<void> delete(String id);
  Future<void> restore(AppNotification n);
}

class MockNotificationsRepository implements NotificationsRepository {
  MockNotificationsRepository()
    : _items = List.of(StudentMockData.notifications);

  final List<AppNotification> _items;

  @override
  Future<List<AppNotification>> getAll() async => List.unmodifiable(_items);

  @override
  Stream<List<AppNotification>> watch() =>
      Stream<List<AppNotification>>.value(List.unmodifiable(_items));

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
  }

  @override
  Future<void> clearAll() async {
    _items.clear();
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> restore(AppNotification n) async {
    _items.insert(0, n);
  }
}
