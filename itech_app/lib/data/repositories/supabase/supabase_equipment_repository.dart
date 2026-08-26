import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../student/models.dart';
import '../auth_exceptions.dart';
import '../equipment_repository.dart';

/// Supabase-backed equipment catalogue. Maps the `equipment` table rows to the
/// existing [Equipment] model so the rest of the app keeps working unchanged.
class SupabaseEquipmentRepository implements EquipmentRepository {
  SupabaseEquipmentRepository();

  SupabaseClient get _client => Supabase.instance.client;

  static Equipment _fromRow(Map<String, dynamic> row) {
    // Migration 0030 embeds this user's own `favorites` row via PostgREST
    // (RLS scopes it to auth.uid(), so it's empty or exactly one row).
    final favs = row['favorites'];
    final liked = favs is List && favs.isNotEmpty;
    return Equipment(
      id: row['id'] as String,
      code: (row['code'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      category: (row['category'] as String?) ?? '',
      location: (row['location'] as String?) ?? '',
      available: (row['available_count'] as int?) ?? 0,
      total: (row['total_count'] as int?) ?? 0,
      description: (row['description'] as String?) ?? '',
      isLiked: liked,
    );
  }

  @override
  Future<List<Equipment>> getAll() async {
    final rows = await _client
        .from('equipment')
        .select('*, favorites ( profile_id )')
        .order('name', ascending: true);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<Equipment?> getById(String id) async {
    final row = await _client
        .from('equipment')
        .select('*, favorites ( profile_id )')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<void> toggleLike(Equipment equipment) async {
    // Persisted against the `favorites` table (migration 0030). The
    // dashboard controller flips its local state optimistically; this call
    // makes it survive reloads. RLS scopes every write to auth.uid().
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const NotSignedInException('toggleLike');
    }
    if (equipment.isLiked) {
      await _client.from('favorites').delete().match({
        'profile_id': uid,
        'equipment_id': equipment.id,
      });
    } else {
      // Upsert (not insert): a double-tap race would otherwise surface a raw
      // unique-violation even though the end state — liked — is correct.
      await _client.from('favorites').upsert({
        'profile_id': uid,
        'equipment_id': equipment.id,
      });
    }
  }
}
