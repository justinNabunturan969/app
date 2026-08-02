import 'borrowings_repository.dart';
import 'equipment_repository.dart';
import 'notifications_repository.dart';
import 'supabase/supabase_borrowings_repository.dart';
import 'supabase/supabase_equipment_repository.dart';
import 'supabase/supabase_notifications_repository.dart';
import 'supabase/supabase_user_repository.dart';
import 'user_repository.dart';

/// Single object the controller depends on. Today the bundle is built
/// with mock implementations; the Supabase swap is a one-line change:
///
/// ```dart
/// final bundle = RepositoryBundle.fromSupabase();
/// ChangeNotifierProvider(
///   create: (_) => StudentDashboardController(bundle: bundle),
/// )
/// ```
class RepositoryBundle {
  const RepositoryBundle({
    required this.equipment,
    required this.borrowings,
    required this.notifications,
    required this.user,
  });

  final EquipmentRepository equipment;
  final BorrowingsRepository borrowings;
  final NotificationsRepository notifications;
  final UserRepository user;

  /// The current build — fully in-memory, no backend required.
  factory RepositoryBundle.mock() {
    return RepositoryBundle(
      equipment: MockEquipmentRepository(),
      borrowings: MockBorrowingsRepository(),
      notifications: MockNotificationsRepository(),
      user: const MockUserRepository(),
    );
  }

  /// Supabase-backed bundle. All four repos hit the same project defined
  /// in `lib/env/supabase_config.dart`. The repositories read the current
  /// user from `Supabase.instance.client.auth.currentUser` on each call,
  /// so they work for both student and admin sessions without any extra
  /// wiring.
  factory RepositoryBundle.fromSupabase() {
    return RepositoryBundle(
      equipment: SupabaseEquipmentRepository(),
      borrowings: SupabaseBorrowingsRepository(),
      notifications: SupabaseNotificationsRepository(),
      user: const SupabaseUserRepository(),
    );
  }
}
