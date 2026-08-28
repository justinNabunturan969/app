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
    final classification = row['classification'] as String?;
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
      classification: classification,
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

  // ── Admin CRUD (migration 0033) ─────────────────────────────────────
  // RLS policy `equipment_admin_write` is `FOR ALL` for `is_admin()`,
  // so these all just hit the table directly — no RPC needed.

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
    // Omit `available_count` — the before-insert trigger
    // (trg_equipment_default_available_count) defaults it to `total_count`.
    final row = await _client
        .from('equipment')
        .insert({
          'code': code,
          'name': name,
          'category': category,
          'location': location,
          'description': description,
          'total_count': totalCount,
          'classification': classification,
        })
        .select('*, favorites ( profile_id )')
        .single();
    return _fromRow(row);
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
    final patch = <String, dynamic>{};
    if (code != null) patch['code'] = code;
    if (name != null) patch['name'] = name;
    if (category != null) patch['category'] = category;
    if (location != null) patch['location'] = location;
    if (description != null) patch['description'] = description;
    if (totalCount != null) patch['total_count'] = totalCount;
    if (availableCount != null) patch['available_count'] = availableCount;
    if (classification != null) patch['classification'] = classification;
    if (patch.isEmpty) {
      final existing = await getById(id);
      if (existing == null) {
        throw StateError('Equipment $id not found');
      }
      return existing;
    }
    final row = await _client
        .from('equipment')
        .update(patch)
        .eq('id', id)
        .select('*, favorites ( profile_id )')
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('equipment').delete().eq('id', id);
  }
}
