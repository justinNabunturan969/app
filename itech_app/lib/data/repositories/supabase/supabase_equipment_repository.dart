import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../equipment_repository.dart';

/// Supabase-backed equipment catalogue. Maps the `equipment` table rows to the
/// existing [Equipment] model so the rest of the app keeps working unchanged.
class SupabaseEquipmentRepository implements EquipmentRepository {
  SupabaseEquipmentRepository();

  SupabaseClient get _client => Supabase.instance.client;

  static Equipment _fromRow(Map<String, dynamic> row) {
    return Equipment(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      category: (row['category'] as String?) ?? '',
      location: (row['location'] as String?) ?? '',
      available: (row['available_count'] as int?) ?? 0,
      total: (row['total_count'] as int?) ?? 0,
      description: (row['description'] as String?) ?? '',
      // "Liked" is client-side state for the thesis prototype; once you add
      // a real favorites table, persist it here and read it back in the
      // select() projection below.
      isLiked: false,
    );
  }

  @override
  Future<List<Equipment>> getAll() async {
    final rows = await _client
        .from('equipment')
        .select()
        .order('name', ascending: true);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<Equipment?> getById(String id) async {
    final row = await _client
        .from('equipment')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<void> toggleLike(Equipment equipment) async {
    // No-op until a `favorites` table exists. The existing prototype treats
    // the heart toggle as in-memory state on the controller side, so the
    // repo can stay a pass-through without breaking the UI.
  }
}
