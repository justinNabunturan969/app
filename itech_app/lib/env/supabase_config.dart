import 'package:flutter/foundation.dart';

/// Supabase project credentials. These come from your project's dashboard at
/// https://supabase.com/dashboard/project/_/settings/api
///
/// Two ways to provide them at build time:
///
/// 1. **Local dev / native builds** — pass with `--dart-define` so they
///    never get committed to source control. The `supabase.json` file in
///    the repo root is loaded by `run.ps1` via `--dart-define-from-file`.
///
/// 2. **Vercel / web deploy** — values are inlined below as the
///    `defaultValue` so a `flutter build web --release` works with no
///    extra flags. The Supabase *anon* key is meant to be public (it's
///    what ships in every browser request), so embedding it for a thesis
///    demo is acceptable. If you ever rotate keys, update them here
///    **and** in the Supabase dashboard, then rebuild.
///
/// To override the inlined values for a one-off build, pass the
/// `--dart-define` flags explicitly — they take precedence over the
/// defaults:
/// ```bash
/// flutter build web --release \
///   --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  // ── Inlined defaults for the deployed demo build ────────────────────
  // These match the project in `supabase.json`. The anon key is a public
  // key (its role is "anon"), so it's safe to ship in client code — RLS
  // policies on the database are what keep your data protected.
  static const String _defaultUrl = 'https://obwdgxcfxxixnuqsjfpu.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2RneGNmeHhpeG51cXNqZnB1Iiwi'
      'cm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MzkwMjYsImV4cCI6MjEwMTIxNTAyNn0.'
      'Nb1VQlS13rmOlbziFSRzVJR80S069yZtb4G-1VqM3WI';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  /// Where Supabase returns the user after they open a password-reset email.
  ///
  /// For web builds the current origin is used automatically, which makes
  /// preview and production Vercel deployments work without hard-coding a
  /// domain. Native builds use the app's registered deep link. A deployment
  /// may override either with `--dart-define=PASSWORD_RESET_REDIRECT_URL=...`.
  static String get passwordResetRedirectUrl {
    const configured = String.fromEnvironment('PASSWORD_RESET_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.resolve('/reset-password').toString();
    return 'pupitech://auth/reset-password';
  }

  /// True if both URL and anon key resolved to a non-empty value. With
  /// the inlined defaults this is always true for production builds, but
  /// the check is still useful for local dev where someone might delete
  /// the defaults.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Throws a startup-friendly error if both the inlined defaults and
  /// the `--dart-define` overrides are empty. Called from `main()` so
  /// the failure mode is obvious (the app never silently talks to a
  /// random project).
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
