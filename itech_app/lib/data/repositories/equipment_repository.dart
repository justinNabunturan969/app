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

  /// Admin: insert a new equipment row. Returns the persisted record (the
  /// Supabase implementation will include the server-assigned `id` and any
  /// defaulted columns, e.g. `available_count` falling back to `total`).
  Future<Equipment> create({
    required String code,
    required String name,
    String? category,
    String? location,
    String? description,
    required int totalCount,
    String? classification,
  });

  /// Admin: update an existing row. Only the fields that are passed get
  /// written; the others are left untouched.
  Future<Equipment> update(
    String id, {
    String? code,
    String? name,
    String? category,
    String? location,
    String? description,
    int? totalCount,
    int? availableCount,
    String? classification,
  });

  /// Admin: delete an equipment row. Throws if the row is referenced by any
  /// non-terminal borrowing (the Supabase RLS + FK constraint will surface
  /// the violation to the caller).
  Future<void> delete(String id);
}

/// Mock implementation — holds a mutable copy of the seed list so the
/// `toggleLike` action works exactly like the previous in-controller
/// behaviour. CRUD operations just mutate the in-memory list.
class MockEquipmentRepository implements EquipmentRepository {
  MockEquipmentRepository() : _items = List.of(StudentMockData.equipment);

  final List<Equipment> _items;
  int _nextId = 100;

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

  @override
  Future<Equipment> create({
    required String code,
    required String name,
    String? category,
    String? location,
    String? description,
    required int totalCount,
    String? classification,
  }) async {
    final id = 'E-${_nextId++}';
    final e = Equipment(
      id: id,
      code: code,
      name: name,
      category: category ?? '',
      location: location ?? '',
      description: description ?? '',
      available: totalCount,
      total: totalCount,
      classification: classification,
    );
    _items.add(e);
    return e;
  }

  @override
  Future<Equipment> update(
    String id, {
    String? code,
    String? name,
    String? category,
    String? location,
    String? description,
    int? totalCount,
    int? availableCount,
    String? classification,
  }) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) {
      throw StateError('Equipment $id not found');
    }
    final current = _items[i];
    final newTotal = totalCount ?? current.total;
    final newAvail = availableCount ?? current.available;
    final next = current.copyWith(
      code: code,
      name: name,
      category: category,
      location: location,
      description: description,
      total: newTotal,
      available: newAvail,
      classification: classification,
    );
    _items[i] = next;
    return next;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }
}
