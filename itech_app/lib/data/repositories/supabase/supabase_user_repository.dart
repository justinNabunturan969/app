import 'package:supabase_flutter/supabase_flutter.dart';

import '../user_repository.dart';

/// Supabase-backed profile repository. Reads the row in `public.profiles`
/// for the currently-authenticated user.
class SupabaseUserRepository implements UserRepository {
  const SupabaseUserRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserProfile> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'SupabaseUserRepository.getCurrentUser called with no signed-in user.',
      );
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile(
      studentId: (row['student_id'] as String?) ?? '',
      studentName: (row['full_name'] as String?) ??
          (row['email'] as String?) ??
          'Student',
      studentEmail: (row['email'] as String?) ?? user.email ?? '',
      studentProgram: (row['program'] as String?) ?? '',
      studentYearLevel: (row['year_level'] as String?) ?? '',
      studentSection: (row['section'] as String?) ?? '',
      memberSince: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
