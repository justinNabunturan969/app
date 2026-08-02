/// Supabase project credentials. These come from your project's dashboard at
/// https://supabase.com/dashboard/project/_/settings/api
///
/// At build / run time, pass them with `--dart-define` so they never get
/// committed to source control:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// The values below are placeholders that throw a clear error at startup if
/// the app is launched without `--dart-define`. This is intentional — it
/// stops you from accidentally shipping placeholder keys to a real device.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// True if both URL and anon key were provided at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Throws a startup-friendly error if the build was launched without the
  /// `--dart-define` flags. Called from `main()` so the failure mode is
  /// obvious (the app never silently talks to a random project).
  static void assertConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase is not configured.\n'
      '\n'
      'Run the app with --dart-define for both:\n'
      '  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co\n'
      '  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY\n'
      '\n'
      'Get these from your Supabase project:\n'
      '  Project Settings -> API -> Project URL / anon public key',
    );
  }
}
