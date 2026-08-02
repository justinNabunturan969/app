import '../../student/mock_data.dart';
import '../../student/models.dart';

/// Contract for the equipment catalogue.
///
/// Today: returns the seed `StudentMockData.equipment` list.
/// Tomorrow: `FirebaseEquipmentRepository` returns a Firestore collection
/// query, optionally with real-time updates via `.snapshots()`.
abstract class EquipmentRepository {
  Future<List<Equipment>> getAll();
  Future<Equipment?> getById(String id);
  Future<void> toggleLike(Equipment equipment);
}

/// Mock implementation — holds a mutable copy of the seed list so the
/// `toggleLike` action works exactly like the previous in-controller
/// behaviour.
class MockEquipmentRepository implements EquipmentRepository {
  MockEquipmentRepository() : _items = List.of(StudentMockData.equipment);

  final List<Equipment> _items;

  @override
  Future<List<Equipment>> getAll() async => List.unmodifiable(_items);

  @override
  Future<Equipment?> getById(String id) async {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<void> toggleLike(Equipment equipment) async {
    final i = _items.indexWhere((e) => e.id == equipment.id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(isLiked: !_items[i].isLiked);
  }
}
